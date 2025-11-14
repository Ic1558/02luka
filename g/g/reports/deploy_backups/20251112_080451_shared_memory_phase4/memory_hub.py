#!/usr/bin/env python3
"""
Unified Memory Hub - Redis-based real-time memory synchronization
"""
import json
import redis
from pathlib import Path
from datetime import datetime
import os
import sys
import time

class UnifiedMemoryHub:
    def __init__(self):
        self.sot_path = Path(os.environ.get('LUKA_SOT', str(Path.home() / '02luka')))
        self.memory_file = self.sot_path / 'shared_memory' / 'context.json'
        self.bridge_dir = self.sot_path / 'bridge' / 'memory'
        
        # Redis connection
        self.redis_client = redis.Redis(
            host=os.environ.get('REDIS_HOST', 'localhost'),
            port=int(os.environ.get('REDIS_PORT', 6379)),
            password=os.environ.get('REDIS_PASSWORD', 'changeme-02luka'),
            decode_responses=True
        )
        
        # Test connection
        try:
            self.redis_client.ping()
        except redis.ConnectionError as e:
            print(f"WARN: Redis not available: {e}", file=sys.stderr)
            self.redis_client = None
        
        # Pub/sub for real-time updates
        self.pubsub = None
        if self.redis_client:
            self.pubsub = self.redis_client.pubsub()
            self.pubsub.subscribe('memory:updates')
    
    def sync_from_file(self):
        """Load context from file system"""
        if self.memory_file.exists():
            try:
                return json.loads(self.memory_file.read_text())
            except json.JSONDecodeError:
                return {"agents": {}, "current_work": {}}
        return {"agents": {}, "current_work": {}}
    
    def sync_to_file(self, data):
        """Save context to file system"""
        self.memory_file.parent.mkdir(parents=True, exist_ok=True)
        data['last_update'] = datetime.now().isoformat()
        self.memory_file.write_text(json.dumps(data, indent=2))
    
    def update_agent_context(self, agent_name, context_update):
        """Update specific agent's context"""
        # Load current state
        data = self.sync_from_file()
        
        # Update agent data
        if agent_name not in data.get('agents', {}):
            data.setdefault('agents', {})[agent_name] = {}
        
        data['agents'][agent_name].update({
            'last_update': datetime.now().isoformat(),
            'context': context_update
        })
        
        # Save to file
        self.sync_to_file(data)
        
        # Update Redis if available
        if self.redis_client:
            try:
                self.redis_client.hset(
                    f'memory:agents:{agent_name}',
                    mapping={
                        'status': 'active',
                        'context': json.dumps(context_update),
                        'last_update': datetime.now().isoformat()
                    }
                )
                
                # Publish update event
                self.redis_client.publish('memory:updates', json.dumps({
                    'agent': agent_name,
                    'event': 'context_update',
                    'timestamp': datetime.now().isoformat(),
                    'data': context_update
                }))
            except Exception as e:
                print(f"WARN: Redis update failed: {e}", file=sys.stderr)
    
    def get_unified_context(self):
        """Get combined context from all agents"""
        # File-based context
        file_context = self.sync_from_file()
        
        # Redis-based context (if available)
        if self.redis_client:
            try:
                redis_context = {}
                for key in self.redis_client.keys('memory:agents:*'):
                    agent_name = key.split(':')[-1]
                    agent_data = self.redis_client.hgetall(key)
                    if agent_data:
                        redis_context[agent_name] = agent_data
                
                # Merge contexts (Redis takes precedence for active data)
                merged = file_context.copy()
                for agent, data in redis_context.items():
                    if agent in merged.get('agents', {}):
                        merged['agents'][agent].update(data)
                    else:
                        merged.setdefault('agents', {})[agent] = data
                
                return merged
            except Exception as e:
                print(f"WARN: Redis read failed: {e}", file=sys.stderr)
        
        return file_context
    
    def run_hub(self):
        """Run hub service continuously"""
        print(f"Memory Hub starting at {datetime.now().isoformat()}")
        
        # Initial sync from file to Redis
        if self.redis_client:
            try:
                file_context = self.sync_from_file()
                for agent, data in file_context.get('agents', {}).items():
                    self.redis_client.hset(
                        f'memory:agents:{agent}',
                        mapping={
                            'status': data.get('status', 'active'),
                            'context': json.dumps(data.get('context', {})),
                            'last_update': data.get('last_update', datetime.now().isoformat())
                        }
                    )
                print("Initial sync to Redis complete")
            except Exception as e:
                print(f"WARN: Initial sync failed: {e}", file=sys.stderr)
        
        # Subscribe to updates
        if self.pubsub:
            print("Subscribed to memory:updates channel")
            for message in self.pubsub.listen():
                if message['type'] == 'message':
                    try:
                        update = json.loads(message['data'])
                        print(f"Received update: {update.get('agent')} - {update.get('event')}")
                        # Sync to file periodically
                        if update.get('event') == 'context_update':
                            unified = self.get_unified_context()
                            self.sync_to_file(unified)
                    except Exception as e:
                        print(f"WARN: Update processing failed: {e}", file=sys.stderr)
        else:
            # Fallback: periodic file sync
            print("Running in file-only mode (Redis unavailable)")
            while True:
                time.sleep(60)  # Sync every minute
                unified = self.get_unified_context()
                self.sync_to_file(unified)

if __name__ == '__main__':
    hub = UnifiedMemoryHub()
    hub.run_hub()
