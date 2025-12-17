#!/usr/bin/env python3
import sqlite3
import json
from datetime import datetime

def generate_html():
    """Generate HTML page with results from SQLite database"""
    conn = sqlite3.connect('results.db')
    cursor = conn.cursor()
    
    # Get all results
    cursor.execute('''
        SELECT username, result, timestamp 
        FROM results 
        ORDER BY timestamp DESC
    ''')
    results = cursor.fetchall()
    
    # Get statistics
    cursor.execute('''
        SELECT 
            COUNT(*) as total_runs,
            AVG(result) as avg_result,
            MIN(result) as min_result,
            MAX(result) as max_result
        FROM results
    ''')
    stats = cursor.fetchone()
    
    cursor.execute('''
        SELECT username, COUNT(*) as run_count, AVG(result) as avg_result
        FROM results
        GROUP BY username
        ORDER BY run_count DESC
    ''')
    user_stats = cursor.fetchall()
    
    conn.close()
    
    # Generate HTML
    html = f'''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Check.py Results</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            .container {{ max-width: 1200px; margin: 0 auto; }}
            .header {{ background: #f4f4f4; padding: 20px; border-radius: 5px; margin-bottom: 30px; }}
            .stats {{ background: #e8f4f8; padding: 20px; border-radius: 5px; margin-bottom: 30px; }}
            table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
            th, td {{ padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }}
            th {{ background-color: #f2f2f2; }}
            tr:hover {{ background-color: #f5f5f5; }}
            .result-high {{ color: green; font-weight: bold; }}
            .result-low {{ color: red; }}
            .timestamp {{ color: #666; font-size: 0.9em; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Check.py Execution Results</h1>
                <p>Automatically updated on each push to check.py</p>
                <p>Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            </div>
            
            <div class="stats">
                <h2>Statistics</h2>
                <p><strong>Total Runs:</strong> {stats[0]}</p>
                <p><strong>Average Result:</strong> {stats[1]:.2f}</p>
                <p><strong>Min Result:</strong> {stats[2]}</p>
                <p><strong>Max Result:</strong> {stats[3]}</p>
            </div>
            
            <h2>User Statistics</h2>
            <table>
                <tr>
                    <th>Username</th>
                    <th>Run Count</th>
                    <th>Average Result</th>
                </tr>
    '''
    
    for username, run_count, avg_result in user_stats:
        html += f'''
                <tr>
                    <td>{username}</td>
                    <td>{run_count}</td>
                    <td>{avg_result:.2f}</td>
                </tr>
        '''
    
    html += '''
            </table>
            
            <h2>Recent Executions</h2>
            <table>
                <tr>
                    <th>Timestamp</th>
                    <th>Username</th>
                    <th>Result</th>
                </tr>
    '''
    
    for username, result, timestamp in results[:50]:  # Show last 50 results
        result_class = "result-high" if result >= 10 else "result-low"
        html += f'''
                <tr>
                    <td class="timestamp">{timestamp}</td>
                    <td>{username}</td>
                    <td class="{result_class}">{result}</td>
                </tr>
        '''
    
    html += '''
            </table>
            
            <div style="margin-top: 40px; padding: 20px; background: #f9f9f9; border-radius: 5px;">
                <h3>About</h3>
                <p>This page displays results from automated executions of check.py.</p>
                <p>Each time check.py is pushed to the repository, a GitHub Action:</p>
                <ol>
                    <li>Executes check.py in a Docker container</li>
                    <li>Stores the result (random integer 0-20) and GitHub username in SQLite</li>
                    <li>Updates this page with the latest results</li>
                </ol>
            </div>
        </div>
    </body>
    </html>
    '''
    
    # Write HTML file
    with open('index.html', 'w') as f:
        f.write(html)
    
    print("Generated index.html")

if __name__ == "__main__":
    generate_html()
    
