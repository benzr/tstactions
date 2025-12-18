#!/usr/bin/env python3
"""
Generate the contest leaderboard HTML page.
"""

import sqlite3
import html
from datetime import datetime

def get_submissions():
    """Get latest submission for each user."""
    conn = sqlite3.connect('results.db')
    conn.row_factory = sqlite3.Row
    
    # Get latest submission per user
    cursor = conn.cursor()
    cursor.execute('''
        SELECT s1.* 
        FROM submissions s1
        INNER JOIN (
            SELECT github_username, MAX(timestamp) as max_time
            FROM submissions 
            GROUP BY github_username
        ) s2 ON s1.github_username = s2.github_username 
             AND s1.timestamp = s2.max_time
        ORDER BY s1.result_score DESC, s1.timestamp ASC
    ''')
    
    submissions = cursor.fetchall()
    
    # Get statistics
    cursor.execute('''
        SELECT 
            COUNT(DISTINCT github_username) as participants,
            AVG(result_score) as avg_score,
            MAX(result_score) as top_score,
            COUNT(*) as total_submissions
        FROM submissions
    ''')
    
    stats = cursor.fetchone()
    conn.close()
    
    return submissions, stats

def generate_html():
    """Generate the HTML leaderboard."""
    submissions, stats = get_submissions()
    
    # Build HTML
    html_content = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Python Contest Leaderboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body {{ background-color: #f8f9fa; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 2rem; border-radius: 10px; margin-bottom: 2rem; }}
        .table {{ background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }}
        .table thead th {{ background-color: #764ba2; color: white; border: none; }}
        .rank-1 {{ background-color: rgba(255, 215, 0, 0.1); }}
        .rank-2 {{ background-color: rgba(192, 192, 192, 0.1); }}
        .rank-3 {{ background-color: rgba(205, 127, 50, 0.1); }}
        .stats-card {{ background: white; border-radius: 10px; padding: 1.5rem; box-shadow: 0 3px 10px rgba(0,0,0,0.08); text-align: center; }}
        .stats-number {{ font-size: 2rem; font-weight: bold; color: #764ba2; }}
        .code-modal pre {{ max-height: 300px; overflow: auto; }}
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header text-center">
            <h1><i class="fas fa-trophy"></i> Python Programming Contest</h1>
            <p class="lead">Exercise 1: Sum of Squares</p>
            <p class="mb-0"><small>Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</small></p>
        </div>
        
        <!-- Statistics -->
        <div class="row mb-4">
            <div class="col-md-3">
                <div class="stats-card">
                    <h5>Participants</h5>
                    <div class="stats-number">{stats['participants'] or 0}</div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="stats-card">
                    <h5>Average Score</h5>
                    <div class="stats-number">{stats['avg_score'] or 0:.1f}</div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="stats-card">
                    <h5>Top Score</h5>
                    <div class="stats-number">{stats['top_score'] or 0}</div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="stats-card">
                    <h5>Submissions</h5>
                    <div class="stats-number">{stats['total_submissions'] or 0}</div>
                </div>
            </div>
        </div>
        
        <!-- Leaderboard Table -->
        <div class="card border-0 shadow">
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead>
                            <tr>
                                <th width="80">Rank</th>
                                <th>GitHub Username</th>
                                <th width="120">Score</th>
                                <th width="150">Tests Passed</th>
                                <th width="180">Last Submission</th>
                                <th width="100">Code</th>
                            </tr>
                        </thead>
                        <tbody>
'''
    
    # Add rows
    for idx, row in enumerate(submissions, 1):
        rank_class = ""
        if idx == 1:
            rank_class = "rank-1"
        elif idx == 2:
            rank_class = "rank-2"
        elif idx == 3:
            rank_class = "rank-3"
        
        time_obj = datetime.strptime(row['timestamp'], '%Y-%m-%d %H:%M:%S')
        time_str = time_obj.strftime('%b %d, %H:%M')
        
        # Escape all user content
        safe_username = html.escape(row['github_username'])
        safe_feedback = html.escape(row['feedback'] or 'No feedback')[:200]
        safe_code = html.escape(row['file_content'])
        
        progress = (row['passed_tests'] / row['total_tests'] * 100) if row['total_tests'] > 0 else 0
        
        html_content += f'''
                            <tr class="{rank_class}">
                                <td><span class="badge bg-secondary">#{idx}</span></td>
                                <td><i class="fab fa-github"></i> <strong>{safe_username}</strong></td>
                                <td>
                                    <span class="badge bg-primary">{row['result_score']}/100</span>
                                </td>
                                <td>
                                    <div class="progress" style="height: 20px;">
                                        <div class="progress-bar {'bg-success' if row['passed_tests'] == row['total_tests'] else 'bg-warning'}" 
                                             role="progressbar" 
                                             style="width: {progress}%">
                                            {row['passed_tests']}/{row['total_tests']}
                                        </div>
                                    </div>
                                </td>
                                <td><small class="text-muted">{time_str}</small></td>
                                <td>
                                    <button class="btn btn-sm btn-outline-primary" 
                                            data-bs-toggle="modal" 
                                            data-bs-target="#modal{row['id']}">
                                        View
                                    </button>
                                </td>
                            </tr>
                            
                            <!-- Modal for this submission -->
                            <div class="modal fade" id="modal{row['id']}" tabindex="-1">
                                <div class="modal-dialog modal-lg">
                                    <div class="modal-content">
                                        <div class="modal-header">
                                            <h5 class="modal-title">
                                                {safe_username}'s Solution
                                                <span class="badge bg-primary ms-2">{row['result_score']}/100</span>
                                            </h5>
                                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                        </div>
                                        <div class="modal-body">
                                            <h6>Source Code:</h6>
                                            <pre class="bg-light p-3 rounded"><code>{safe_code}</code></pre>
                                            <h6 class="mt-3">Feedback:</h6>
                                            <div class="bg-light p-3 rounded">
                                                {safe_feedback.replace(chr(10), '<br>')}
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
'''
    
    html_content += '''
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        
        <div class="text-center mt-4 text-muted">
            <p>This leaderboard updates automatically after each submission is merged.</p>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Auto-refresh every 60 seconds
        setTimeout(function() { location.reload(); }, 60000);
    </script>
</body>
</html>
'''
    
    # Write to file
    with open('index.html', 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"Generated leaderboard with {len(submissions)} participants")

if __name__ == "__main__":
    generate_html()