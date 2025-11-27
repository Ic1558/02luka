from agents.clc.model_router import THRESHOLD_FILES, should_route_to_clc


def test_requires_clc_routes():
    wo = {"requires_clc": True}
    assert should_route_to_clc(wo) == "clc_local"


def test_complexity_routes():
    wo = {"complexity": "complex"}
    assert should_route_to_clc(wo) == "clc_local"


def test_file_count_routes():
    wo = {"file_count": THRESHOLD_FILES + 1}
    assert should_route_to_clc(wo) == "clc_local"


def test_simple_single_file_does_not_route():
    wo = {"complexity": "simple", "file_count": 1}
    assert should_route_to_clc(wo) is None


def test_files_list_routes_based_on_length():
    wo = {"files": ["a", "b", "c", "d"]}
    assert should_route_to_clc(wo) == "clc_local"
