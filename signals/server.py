"""Lightweight Flask server providing signal, training, and backtesting APIs.

This service simulates a simple quantitative workflow by training three
independent models (XGBoost, Logistic Regression, and an LSTM network) on a
synthetic price series enhanced with technical indicators from ``pandas_ta``.
The resulting artefacts and metadata are persisted under ``signals/models`` and
served through a set of HTTP endpoints.
"""
from __future__ import annotations

import json
import os
import threading
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import joblib
import numpy as np
import pandas as pd
import pandas_ta as ta  # noqa: F401  # Imported for the pandas_ta accessor
from flask import Flask, jsonify, request
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, log_loss
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier

# Import TensorFlow lazily to keep module import light when only health endpoints
# are invoked. TensorFlow initialises CUDA/CPU backends on import, so deferring it
# avoids unnecessary overhead for simple requests.
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.layers import LSTM, Dense
from tensorflow.keras.models import Sequential, load_model

app = Flask(__name__)

BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = BASE_DIR / "models"
CONFIG_FILE = MODEL_DIR / "config.json"

MODEL_FILENAMES = {
    "lr": MODEL_DIR / "lr_model.pkl",
    "xgb": MODEL_DIR / "xgb_model.pkl",
    "lstm": MODEL_DIR / "lstm_model.h5",
    "scaler": MODEL_DIR / "scaler.pkl",
}

MAX_CONCURRENT_TRAINING = 2
_TRAINING_SEMAPHORE = threading.Semaphore(MAX_CONCURRENT_TRAINING)
_MODEL_CACHE: Dict[str, Any] = {}


@dataclass
class TrainingConfig:
    """Runtime configuration saved alongside training artefacts."""

    version: str
    trained_at: str
    feature_columns: List[str]
    lookback: int
    metrics: Dict[str, Dict[str, float]]

    @property
    def serialisable(self) -> Dict[str, Any]:
        return {
            "version": self.version,
            "trained_at": self.trained_at,
            "feature_columns": self.feature_columns,
            "lookback": self.lookback,
            "metrics": self.metrics,
        }


def _ensure_model_dir() -> None:
    MODEL_DIR.mkdir(parents=True, exist_ok=True)


def _load_history() -> Dict[str, Any]:
    if CONFIG_FILE.exists():
        with CONFIG_FILE.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    return {"history": []}


def _save_history(config: TrainingConfig) -> None:
    history = _load_history()
    history.setdefault("history", [])
    history_entry = config.serialisable
    history["latest_version"] = config.version
    history["trained_at"] = config.trained_at
    history["metrics"] = config.metrics
    history["feature_columns"] = config.feature_columns
    history["lookback"] = config.lookback

    # Append the current configuration to history while deduplicating by version.
    history_list = [
        entry for entry in history["history"] if entry.get("version") != config.version
    ]
    history_list.append(history_entry)
    history["history"] = sorted(
        history_list,
        key=lambda item: item.get("trained_at", ""),
        reverse=True,
    )

    with CONFIG_FILE.open("w", encoding="utf-8") as fh:
        json.dump(history, fh, indent=2)


def _load_training_config() -> Optional[TrainingConfig]:
    if not CONFIG_FILE.exists():
        return None
    data = _load_history()
    version = data.get("latest_version")
    trained_at = data.get("trained_at")
    feature_columns = data.get("feature_columns")
    lookback = data.get("lookback")
    metrics = data.get("metrics")
    if not all([version, trained_at, feature_columns, lookback]):
        return None
    return TrainingConfig(
        version=version,
        trained_at=trained_at,
        feature_columns=feature_columns,
        lookback=int(lookback),
        metrics=metrics or {},
    )


def _load_joblib_model(name: str) -> Any:
    model_path = MODEL_FILENAMES[name]
    if not model_path.exists():
        return None
    if name not in _MODEL_CACHE:
        _MODEL_CACHE[name] = joblib.load(model_path)
    return _MODEL_CACHE[name]


def _load_lstm_model() -> Any:
    model_path = MODEL_FILENAMES["lstm"]
    if not model_path.exists():
        return None
    if "lstm" not in _MODEL_CACHE:
        _MODEL_CACHE["lstm"] = load_model(model_path)
    return _MODEL_CACHE["lstm"]


def _load_models() -> Tuple[Any, Any, Any, Any, Optional[TrainingConfig]]:
    config = _load_training_config()
    scaler = _load_joblib_model("scaler")
    lr_model = _load_joblib_model("lr")
    xgb_model = _load_joblib_model("xgb")
    lstm_model = _load_lstm_model()
    return scaler, lr_model, xgb_model, lstm_model, config


def _generate_synthetic_prices(length: int = 1500, seed: Optional[int] = None) -> np.ndarray:
    rng = np.random.default_rng(seed)
    steps = rng.normal(loc=0.0, scale=1.0, size=length)
    prices = 100 + np.cumsum(steps)
    # Ensure strictly positive prices
    return np.maximum(prices, 1.0)


def _feature_dataframe(prices: np.ndarray) -> pd.DataFrame:
    df = pd.DataFrame({"close": prices})
    df["return"] = df["close"].pct_change()
    df.ta.sma(length=5, append=True)
    df.ta.sma(length=10, append=True)
    df.ta.ema(length=12, append=True)
    df.ta.ema(length=26, append=True)
    df.ta.rsi(length=14, append=True)
    macd = df.ta.macd(append=True)
    if macd is not None:
        df = pd.concat([df, macd], axis=1)
    df["future_return"] = df["close"].pct_change().shift(-1)
    df["target"] = (df["future_return"] > 0).astype(int)
    df = df.dropna().reset_index(drop=True)
    df.columns = [col.lower() for col in df.columns]
    return df


def _create_sequences(
    features: np.ndarray, targets: np.ndarray, lookback: int
) -> Tuple[np.ndarray, np.ndarray]:
    if lookback <= 0:
        raise ValueError("lookback must be positive")
    if len(features) != len(targets):
        raise ValueError("features and targets must have the same length")
    sequences: List[np.ndarray] = []
    seq_targets: List[float] = []
    for idx in range(lookback, len(features)):
        window = features[idx - lookback : idx]
        sequences.append(window)
        seq_targets.append(float(targets[idx]))
    if not sequences:
        return np.empty((0, lookback, features.shape[1])), np.empty((0,), dtype=np.float32)
    return np.asarray(sequences, dtype=np.float32), np.asarray(seq_targets, dtype=np.float32)


def _build_lstm(input_shape: Tuple[int, int]) -> Sequential:
    model = Sequential(
        [
            LSTM(32, input_shape=input_shape, activation="tanh"),
            Dense(16, activation="relu"),
            Dense(1, activation="sigmoid"),
        ]
    )
    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy"])
    return model


def _train_models(payload: Dict[str, Any]) -> TrainingConfig:
    seed = payload.get("seed") if isinstance(payload, dict) else None
    length = int(payload.get("length", 1500)) if isinstance(payload, dict) else 1500
    lookback = int(payload.get("lookback", 5)) if isinstance(payload, dict) else 5

    prices = _generate_synthetic_prices(length=length, seed=seed)
    data = _feature_dataframe(prices)

    feature_columns = [col for col in data.columns if col not in {"target", "future_return"}]
    X = data[feature_columns]
    y = data["target"].astype(int)

    split_idx = int(len(X) * 0.8)
    X_train_raw, X_test_raw = X.iloc[:split_idx], X.iloc[split_idx:]
    y_train_raw, y_test_raw = y.iloc[:split_idx], y.iloc[split_idx:]

    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train_raw)
    X_test_scaled = scaler.transform(X_test_raw)

    lr_model = LogisticRegression(max_iter=1000)
    lr_model.fit(X_train_scaled, y_train_raw)

    xgb_model = XGBClassifier(
        n_estimators=200,
        max_depth=4,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        reg_lambda=1.0,
        objective="binary:logistic",
        eval_metric="logloss",
        use_label_encoder=False,
        verbosity=0,
    )
    xgb_model.fit(X_train_scaled, y_train_raw, eval_set=[(X_test_scaled, y_test_raw)], verbose=False)

    train_sequences, train_targets = _create_sequences(X_train_scaled, y_train_raw.values, lookback)
    test_sequences, test_targets = _create_sequences(X_test_scaled, y_test_raw.values, lookback)

    lstm_model = _build_lstm((lookback, X_train_scaled.shape[1]))
    callbacks = [EarlyStopping(monitor="val_loss", patience=3, restore_best_weights=True)]
    validation_data = (test_sequences, test_targets) if len(test_sequences) else None
    lstm_model.fit(
        train_sequences,
        train_targets,
        validation_data=validation_data,
        epochs=25,
        batch_size=32,
        verbose=0,
        callbacks=callbacks,
    )

    lr_probs = lr_model.predict_proba(X_test_scaled)[:, 1]
    lr_pred = (lr_probs > 0.5).astype(int)
    xgb_probs = xgb_model.predict_proba(X_test_scaled)[:, 1]
    xgb_pred = (xgb_probs > 0.5).astype(int)

    metrics = {
        "logistic_regression": {
            "accuracy": float(accuracy_score(y_test_raw, lr_pred)),
            "log_loss": float(log_loss(y_test_raw, lr_probs)),
        },
        "xgboost": {
            "accuracy": float(accuracy_score(y_test_raw, xgb_pred)),
            "log_loss": float(log_loss(y_test_raw, xgb_probs)),
        },
    }

    if len(test_sequences):
        lstm_probs = lstm_model.predict(test_sequences, verbose=0).flatten()
        lstm_pred = (lstm_probs > 0.5).astype(int)
        metrics["lstm"] = {
            "accuracy": float(accuracy_score(test_targets, lstm_pred)),
            "log_loss": float(log_loss(test_targets, lstm_probs)),
        }
    else:
        metrics["lstm"] = {"accuracy": float("nan"), "log_loss": float("nan")}

    timestamp = datetime.utcnow().isoformat() + "Z"
    version = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    config = TrainingConfig(
        version=version,
        trained_at=timestamp,
        feature_columns=feature_columns,
        lookback=lookback,
        metrics=metrics,
    )

    _ensure_model_dir()
    joblib.dump(lr_model, MODEL_FILENAMES["lr"])
    joblib.dump(xgb_model, MODEL_FILENAMES["xgb"])
    joblib.dump(scaler, MODEL_FILENAMES["scaler"])
    lstm_model.save(MODEL_FILENAMES["lstm"], include_optimizer=True)

    # Invalidate cache to force reload of new artefacts.
    _MODEL_CACHE.clear()

    _save_history(config)

    return config


def _prepare_features_from_prices(
    prices: List[float], config: TrainingConfig
) -> Tuple[pd.DataFrame, pd.DataFrame]:
    if not prices or len(prices) < max(config.lookback + 5, 20):
        raise ValueError("prices array is too short to compute indicators")
    frame = _feature_dataframe(np.asarray(prices, dtype=float))
    if len(frame) < config.lookback + 1:
        raise ValueError("not enough feature rows computed")
    features = frame[config.feature_columns]
    return frame, features


def _aggregate_signal(
    probabilities: List[float], threshold_buy: float = 0.55, threshold_sell: float = 0.45
) -> Tuple[str, float]:
    if not probabilities:
        return "hold", 0.0
    avg_prob = float(np.mean(probabilities))
    if avg_prob >= threshold_buy:
        return "buy", min(1.0, (avg_prob - 0.5) * 2)
    if avg_prob <= threshold_sell:
        return "sell", min(1.0, (0.5 - avg_prob) * 2)
    return "hold", max(0.0, 1.0 - abs(avg_prob - 0.5) * 4)


@app.route("/health", methods=["GET"])
def health() -> Any:
    history = _load_history().get("history", [])
    versions = [entry.get("version") for entry in history]
    return jsonify({"status": "ok", "models": versions})


@app.route("/train", methods=["POST"])
def train_endpoint() -> Any:
    if not _TRAINING_SEMAPHORE.acquire(blocking=False):
        return jsonify({"error": "too many concurrent training jobs"}), 429

    payload = request.get_json(silent=True) or {}
    try:
        config = _train_models(payload)
    except Exception as exc:  # noqa: BLE001 - surface training error to caller
        return jsonify({"error": str(exc)}), 500
    finally:
        _TRAINING_SEMAPHORE.release()

    return jsonify({
        "version": config.version,
        "trained_at": config.trained_at,
        "metrics": config.metrics,
    })


@app.route("/signal", methods=["POST"])
def signal_endpoint() -> Any:
    scaler, lr_model, xgb_model, lstm_model, config = _load_models()
    if not config or not all([scaler, lr_model, xgb_model, lstm_model]):
        return jsonify({"error": "models are not trained yet"}), 400

    payload = request.get_json(silent=True) or {}
    prices = payload.get("prices")
    if not isinstance(prices, list):
        return jsonify({"error": "request must include a list of prices"}), 400

    try:
        frame, features = _prepare_features_from_prices(prices, config)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    latest_features = features.iloc[[-1]]
    scaled_latest = scaler.transform(latest_features)

    lr_prob = float(lr_model.predict_proba(scaled_latest)[0, 1])
    xgb_prob = float(xgb_model.predict_proba(scaled_latest)[0, 1])

    # Prepare LSTM input using the configured lookback window.
    lookback = config.lookback
    scaled_matrix = scaler.transform(features.iloc[-lookback:])
    lstm_input = scaled_matrix[np.newaxis, :, :]
    lstm_prob = float(lstm_model.predict(lstm_input, verbose=0).flatten()[0])

    probabilities = [lr_prob, xgb_prob, lstm_prob]
    signal, confidence = _aggregate_signal(probabilities)
    votes = sum(prob > 0.5 for prob in probabilities)

    return jsonify({
        "signal": signal,
        "confidence": confidence,
        "votes": votes,
        "probabilities": {
            "logistic_regression": lr_prob,
            "xgboost": xgb_prob,
            "lstm": lstm_prob,
        },
        "price": frame["close"].iloc[-1],
        "version": config.version,
    })


@app.route("/models", methods=["GET"])
def models_endpoint() -> Any:
    history = _load_history().get("history", [])
    return jsonify(history)


def _run_backtest(payload: Dict[str, Any]) -> Dict[str, Any]:
    scaler, lr_model, xgb_model, lstm_model, config = _load_models()
    if not config or not all([scaler, lr_model, xgb_model, lstm_model]):
        raise ValueError("models are not trained yet")

    seed = payload.get("seed") if isinstance(payload, dict) else None
    length = int(payload.get("length", 600)) if isinstance(payload, dict) else 600

    prices = _generate_synthetic_prices(length=length, seed=seed)
    frame = _feature_dataframe(prices)
    features = frame[config.feature_columns]
    lookback = config.lookback

    signals: List[str] = []

    for idx in range(lookback, len(features)):
        window_features = features.iloc[idx - lookback : idx]
        current_features = features.iloc[[idx]]

        scaled_current = scaler.transform(current_features)
        lr_prob = float(lr_model.predict_proba(scaled_current)[0, 1])
        xgb_prob = float(xgb_model.predict_proba(scaled_current)[0, 1])

        scaled_window = scaler.transform(window_features)
        lstm_input = scaled_window[np.newaxis, :, :]
        lstm_prob = float(lstm_model.predict(lstm_input, verbose=0).flatten()[0])

        probabilities = [lr_prob, xgb_prob, lstm_prob]
        signal, _ = _aggregate_signal(probabilities)

        signals.append(signal)

    price_series = frame["close"].iloc[lookback:].reset_index(drop=True)
    returns = price_series.pct_change().shift(-1).fillna(0.0)
    position_map = {"buy": 1, "sell": -1, "hold": 0}
    positions = np.array([position_map[s] for s in signals])
    strategy_returns = returns.iloc[: len(positions)].to_numpy() * positions

    active_mask = positions != 0
    active_returns = strategy_returns[active_mask]

    cumulative_return = float(np.prod(1 + strategy_returns) - 1)
    hit_rate = float(
        np.mean(active_returns > 0) if active_returns.size else 0.0
    )
    avg_trade_return = float(np.mean(active_returns) if active_returns.size else 0.0)

    return {
        "cumulative_return": cumulative_return,
        "hit_rate": hit_rate,
        "average_trade_return": avg_trade_return,
        "num_trades": int(active_mask.sum()),
        "observations": len(strategy_returns),
    }


@app.route("/backtest", methods=["POST"])
def backtest_endpoint() -> Any:
    payload = request.get_json(silent=True) or {}
    try:
        result = _run_backtest(payload)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    except Exception as exc:  # noqa: BLE001
        return jsonify({"error": str(exc)}), 500
    return jsonify(result)


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)
