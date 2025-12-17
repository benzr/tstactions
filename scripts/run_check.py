#!/usr/bin/env python3
import sqlite3
import random
import os
import sys
import subprocess

def get_github_actor():
    """Get GitHub username from environment variables"""
    return os.getenv('GITHUB_ACTOR', 'unknown')

def run_check():
    """Execute check.py and get result"""
    try:
        # Import or execute check.py
        import check
        if hasattr(check, 'main'):
            result = check.main()
        else:
            # Default: generate random number
            result = random.randint(0, 20)
    except Exception as e:
        print(f"Error running check.py: {e}")
        result = random.randint(0, 20)
    
    return result

def store_result(username, result):
    """Store result in SQLite database"""
    conn = sqlite3.connect('/github/workspace/results.db')
    cursor = conn.cursor()
    
    # Create table if not exists
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            username TEXT,
            result INTEGER
        )
    ''')
    
    # Insert result
    cursor.execute('''
        INSERT INTO results (username, result)
        VALUES (?, ?)
    ''', (username, result))
    
    conn.commit()
    conn.close()

def main():
    username = get_github_actor()
    result = run_check()
    
    print(f"Username: {username}")
    print(f"Result: {result}")
    
    store_result(username, result)
    
    # Return result for GitHub Actions
    print(f"::set-output name=result::{result}")
    return result

if __name__ == "__main__":
    main()
    
