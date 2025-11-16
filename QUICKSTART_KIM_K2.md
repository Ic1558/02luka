# Quick Start – Kim K2 Profiles

1. **Start Dispatcher**
   ```bash
   cd ~/02luka/core/nlp
   ./start_dispatcher.sh
   ```

2. **Telegram Commands**
   - `/use kim_k2_poc` – Switch chat to K2 (persists for 30 days).
   - `/k2 <prompt>` – One-off question through K2.
   - `/use default` – Return to legacy Kim routing.

3. **CLI Testing**
   ```bash
   python3 ~/02luka/tools/kim_nlp_publish.py "test message"
   ~/02luka/tools/kim_ab_test.zsh "Explain quantum computing"
   ```

4. **Health Check**
   ```bash
   ~/02luka/tools/kim_health_check.zsh
   ```

5. **Documentation**
   - `reports/system/kim_k2_finalize_README.md`
   - `reports/system/kim_k2_tgcmds_README.md`
   - `reports/system/kim_k2_deployment_complete.md`
