# Local Agent Integration

This file is generated from local LaunchAgents. Do not edit by hand.

## Roster
- **com.02luka.autostart** — `/bin/echo`  
- **com.02luka.boot.guard** — `/bin/bash` — every 600s 
- **com.02luka.boss.audit** — `/bin/bash`  — calendar Dict {
    Hour = 8
    Minute = 0
}
- **com.02luka.boss.drop.watcher** — `/bin/bash`  
- **com.02luka.boss.dropbox.watcher** — `/bin/bash` — every 30s 
- **com.02luka.boss.sent.watcher** — `/bin/bash` — every 30s 
- **com.02luka.calendar.build** — `bash` — every 600s 
- **com.02luka.calendar.sync** — `bash` — every 1800s 
- **com.02luka.clc.executor** — `python3`  
- **com.02luka.clc_inbox_watcher** — `/bin/bash`  
- **com.02luka.cloudflared.dashboard** — `/opt/homebrew/bin/cloudflared`  
- **com.02luka.cloudflared.nas-archive** — `/bin/bash`  
- **Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.core.mary_core.plist
com.02luka.core.mary_core** — `Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.core.mary_core.plist` — every Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.core.mary_core.plists — calendar Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.core.mary_core.plist
- **com.02luka.daily-report.publish** — `/bin/bash`  — calendar Dict {
    Hour = 23
    Minute = 55
}
- **com.02luka.daily.audit** — `/bin/bash`  — calendar Dict {
    Hour = 7
    Minute = 30
}
- **com.02luka.daily.verify** — `/bin/bash`  — calendar Dict {
    Hour = 8
    Minute = 0
}
- **com.02luka.daily_wo_rollup** — `/bin/bash`  — calendar Dict {
    Hour = 23
    Minute = 55
}
- **com.02luka.discovery.merge.daily** — `/bin/bash`  — calendar Dict {
    Hour = 3
    Minute = 0
}
- **com.02luka.distribute.daily.learning** — `/bin/bash`  — calendar Dict {
    Hour = 23
    Minute = 55
}
- **com.02luka.fastvlm.cron** — `/bin/zsh` — every 21600s 
- **com.02luka.fastvlm** — `bash`  
- **com.02luka.fleet.supervisor** — `bash` — every 300s 
- **com.02luka.gc_core** — `/bin/bash`  
- **com.02luka.gci.env** — `/bin/launchctl`  
- **com.02luka.gd.guard** — `/usr/bin/python3`  
- **com.02luka.gemini.cli.env** — `/bin/launchctl`  
- **com.02luka.gg_local_llm** — `/opt/homebrew/bin/python3`  
- **com.02luka.gptree_events** — `/opt/homebrew/bin/python3`  
- **com.02luka.gptree_updater** — `/opt/homebrew/bin/python3` — every 600s 
- **com.02luka.health.proxy** — `/bin/bash`  
- **com.02luka.health_monitor** — `/opt/homebrew/bin/python3`  
- **com.02luka.heartbeats** — `/bin/sh` — every 15s 
- **com.02luka.inbox_daemon** — `bash` — every 300s 
- **com.02luka.index_uplink** — `/bin/bash` — every 600s 
- **com.02luka.intelligent_librarian** — `/usr/bin/python3` — every 2400s 
- **com.02luka.librarian.v2** — `/usr/bin/python3`  
- **com.02luka.llm-router** — `/usr/bin/python3`  
- **com.02luka.localworker.bg** — `bash`  
- **com.02luka.logrotate.daily** — `/opt/homebrew/sbin/logrotate` — every 86400s 
- **com.02luka.mcp.fs** — `/bin/bash`  
- **com.02luka.mcp.server.fs_local** — `/bin/bash`  
- **com.02luka.mcp.webbridge** — `/opt/homebrew/bin/python3`  
- **com.02luka.nightly.selftest** — `/bin/bash`  — calendar Dict {
    Hour = 2
    Minute = 30
}
- **com.02luka.ollama-bridge** — `/usr/bin/python3` — every 5s 
- **com.02luka.ollama-desktop-bridge** — `/bin/bash`  
- **com.02luka.paula_av_sanity** — `/usr/bin/python3`  — calendar Array {
    Dict {
        Hour = 9
        Minute = 0
    }
    Dict {
        Hour = 11
        Minute = 0
    }
    Dict {
        Hour = 13
        Minute = 0
    }
    Dict {
        Hour = 15
        Minute = 0
    }
    Dict {
        Hour = 17
        Minute = 0
    }
}
- **com.02luka.paula_av_watch** — `/usr/bin/python3`  
- **com.02luka.redis_bridge** — `bash`  
- **com.02luka.routine_delegation** — `/opt/homebrew/bin/python3`  
- **Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.security.scan.plist
com.02luka.security.scan** — `Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.security.scan.plist` — every Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.security.scan.plists — calendar Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.security.scan.plist
- **com.02luka.shadow_rsync** — `/bin/bash` — every 900s 
- **com.02luka.simple.watchdog** — `/opt/homebrew/Cellar/python@3.13/3.13.5/Frameworks/Python.framework/Versions/3.13/Resources/Python.app/Contents/MacOS/Python`  
- **com.02luka.sot.enforcement** — `/bin/bash` — every 86400s 
- **Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.sr_echo_consumer.smoke4.plist
com.02luka.sr_echo_consumer.smoke4** — `Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.sr_echo_consumer.smoke4.plist` — every Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.sr_echo_consumer.smoke4.plists — calendar Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.sr_echo_consumer.smoke4.plist
- **com.02luka.status.bridge** — `/usr/bin/env`  
- **com.02luka.status.snapshot** — `/bin/echo`  
- **com.02luka.sync.cache** — `/bin/bash` — every 3600s 
- **com.02luka.system_runner.hc** — `/bin/bash` — every 900s 
- **com.02luka.system_runner** — `/bin/bash` — every 300s 
- **com.02luka.system_runner.v5** — `bash`  
- **com.02luka.system_runner_health** — `/usr/bin/python3` — every 60s 
- **com.02luka.task.bus.bridge** — `/bin/bash`  
- **Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.tasks_reconciler.plist
com.02luka.tasks_reconciler** — `Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.tasks_reconciler.plist` — every Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.tasks_reconciler.plists — calendar Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.tasks_reconciler.plist
- **com.02luka.telegram-bridge** — `/bin/bash` — every 5s 
- **com.02luka.terminalhandler** — `/usr/bin/env`  
- **Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.test.mary.plist
com.02luka.test.mary** — `Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.test.mary.plist` — every Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.test.mary.plists — calendar Error Reading File: /Users/icmini/Library/LaunchAgents/com.02luka.test.mary.plist
- **com.02luka.update_truth** — `/bin/sh` — every 300s 
- **com.02luka.watchdog** — `/bin/bash` — every 60s 
- **com.02luka.watcher** — `/opt/homebrew/bin/python3`  
- **com.02luka.wo_doctor** — `/bin/bash` — every 120s 

## Logs
- Path: `/Users/icmini/Library/Logs/02luka/`
