#!/usr/bin/env python3
"""
Log cleanup utility for SniffTest API
Cleans up old logs and implements log rotation
"""

import os
import shutil
import gzip
from datetime import datetime, timedelta
from pathlib import Path


def cleanup_audit_logs(log_file: str = "audit.log", max_size_mb: int = 10, keep_days: int = 30):
    """
    Clean up audit logs by compressing old entries and removing very old ones
    
    Args:
        log_file: Path to the audit log file
        max_size_mb: Maximum size before compression (in MB)
        keep_days: Number of days to keep compressed logs
    """
    if not os.path.exists(log_file):
        print(f"Log file {log_file} not found")
        return
    
    # Get file size in MB
    file_size_mb = os.path.getsize(log_file) / (1024 * 1024)
    print(f"Current log file size: {file_size_mb:.2f} MB")
    
    if file_size_mb < max_size_mb:
        print("Log file size is within limits, no cleanup needed")
        return
    
    # Create backup directory
    backup_dir = Path("logs_backup")
    backup_dir.mkdir(exist_ok=True)
    
    # Generate timestamp for backup
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = backup_dir / f"audit_{timestamp}.log.gz"
    
    # Compress current log
    print(f"Compressing log file to {backup_file}")
    with open(log_file, 'rb') as f_in:
        with gzip.open(backup_file, 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)
    
    # Clear the original log file
    with open(log_file, 'w') as f:
        f.write("")
    
    print(f"Log file compressed and cleared. Backup saved to {backup_file}")
    
    # Clean up old backups
    cutoff_date = datetime.now() - timedelta(days=keep_days)
    removed_count = 0
    
    for backup in backup_dir.glob("audit_*.log.gz"):
        # Extract date from filename
        try:
            date_str = backup.stem.split('_')[1]  # Get date part
            backup_date = datetime.strptime(date_str, "%Y%m%d")
            
            if backup_date < cutoff_date:
                backup.unlink()
                removed_count += 1
                print(f"Removed old backup: {backup}")
        except (ValueError, IndexError):
            # Skip files that don't match expected format
            continue
    
    print(f"Removed {removed_count} old backup files")


def analyze_log_patterns(log_file: str = "audit.log"):
    """
    Analyze log patterns to identify common issues
    
    Args:
        log_file: Path to the audit log file
    """
    if not os.path.exists(log_file):
        print(f"Log file {log_file} not found")
        return
    
    print(f"\nAnalyzing log patterns in {log_file}...")
    
    # Count different types of events
    event_counts = {}
    error_counts = {}
    endpoint_counts = {}
    
    with open(log_file, 'r') as f:
        for line in f:
            try:
                # Parse JSON log entry
                import json
                log_entry = json.loads(line.split(' - ', 2)[2])  # Skip timestamp and level
                
                event_type = log_entry.get('event_type', 'unknown')
                status_code = log_entry.get('status_code', 0)
                path = log_entry.get('path', 'unknown')
                
                # Count events
                event_counts[event_type] = event_counts.get(event_type, 0) + 1
                
                # Count errors
                if status_code >= 400:
                    error_counts[status_code] = error_counts.get(status_code, 0) + 1
                
                # Count endpoints
                endpoint_counts[path] = endpoint_counts.get(path, 0) + 1
                
            except (json.JSONDecodeError, IndexError, KeyError):
                # Skip malformed log entries
                continue
    
    # Print analysis
    print("\nEvent Type Distribution:")
    for event_type, count in sorted(event_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"  {event_type}: {count}")
    
    print("\nError Status Codes:")
    for status_code, count in sorted(error_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"  {status_code}: {count}")
    
    print("\nMost Accessed Endpoints:")
    for path, count in sorted(endpoint_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"  {path}: {count}")


def optimize_log_entries(log_file: str = "audit.log"):
    """
    Optimize log entries by removing redundant information
    
    Args:
        log_file: Path to the audit log file
    """
    if not os.path.exists(log_file):
        print(f"Log file {log_file} not found")
        return
    
    print(f"Optimizing log entries in {log_file}...")
    
    # Read all log entries
    entries = []
    with open(log_file, 'r') as f:
        for line in f:
            entries.append(line.strip())
    
    # Remove duplicate consecutive entries (same path, method, status)
    optimized_entries = []
    last_entry = None
    duplicate_count = 0
    
    for entry in entries:
        try:
            import json
            log_entry = json.loads(entry.split(' - ', 2)[2])
            
            # Create a simplified key for comparison
            key = (
                log_entry.get('path', ''),
                log_entry.get('method', ''),
                log_entry.get('status_code', 0)
            )
            
            if key != last_entry:
                optimized_entries.append(entry)
                last_entry = key
            else:
                duplicate_count += 1
                
        except (json.JSONDecodeError, IndexError, KeyError):
            # Keep malformed entries as-is
            optimized_entries.append(entry)
    
    # Write optimized entries back
    with open(log_file, 'w') as f:
        for entry in optimized_entries:
            f.write(entry + '\n')
    
    print(f"Removed {duplicate_count} duplicate entries")
    print(f"Log file optimized: {len(entries)} -> {len(optimized_entries)} entries")


if __name__ == "__main__":
    print("SniffTest - Log Cleanup Utility")
    print("=" * 50)
    
    # Analyze current logs
    analyze_log_patterns()
    
    # Optimize log entries
    optimize_log_entries()
    
    # Clean up if needed
    cleanup_audit_logs()
    
    print("\nLog cleanup completed!")
