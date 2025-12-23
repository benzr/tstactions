#!/usr/bin/env python3
"""
Evaluator for student submissions.
Usage: python evaluator.py <submission_file> <github_username>
"""

import sys
import sqlite3
import importlib.util
from pathlib import Path
from datetime import datetime

def evaluate_submission(file_path, database_path, github_username):
    """Evaluate a student's submission and return score."""
    module_name = Path(file_path).stem
    
    try:
        # Dynamically import student's module
        spec = importlib.util.spec_from_file_location(module_name, file_path)
        student_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(student_module)
        
        score = 0
        feedback = []
        passed_tests = 0
        total_tests = 5  # We have 5 tests total
        
        # TEST 1: Function exists
        if hasattr(student_module, 'sum_of_squares'):
            passed_tests += 1
            score += 20
            feedback.append("✓ Function 'sum_of_squares' exists")
            
            func = student_module.sum_of_squares
            
            # TEST 2-5: Run test cases
            test_cases = [
                (1, 1, "sum_of_squares(1) = 1"),
                (5, 55, "sum_of_squares(5) = 55"),
                (10, 385, "sum_of_squares(10) = 385"),
                (0, 0, "sum_of_squares(0) = 0")
            ]
            
            for n, expected, description in test_cases:
                try:
                    result = func(n)
                    if result == expected:
                        passed_tests += 1
                        score += 20
                        feedback.append(f"✓ {description}")
                    else:
                        feedback.append(f"✗ {description} (got {result}, expected {expected})")
                except Exception as e:
                    feedback.append(f"✗ {description} raised {type(e).__name__}: {str(e)[:50]}")
        else:
            feedback.append("✗ Missing required function 'sum_of_squares'")
        
    except Exception as e:
        score = 0
        passed_tests = 0
        total_tests = 1
        feedback = [f"❌ Import/Execution failed: {type(e).__name__}: {str(e)[:100]}"]
    
    # Store results in database
    conn = sqlite3.connect(database_path)
    cursor = conn.cursor()
    
    # Ensure table exists
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS submissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            github_username TEXT NOT NULL,
            exercise_name TEXT NOT NULL,
            result_score INTEGER,
            file_content TEXT NOT NULL,
            passed_tests INTEGER,
            total_tests INTEGER,
            feedback TEXT
        )
    ''')
    
    # Read student's source code
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            file_content = f.read()
    except Exception as e:
        file_content = f"Error reading file: {e}"
    
    # Insert submission
    cursor.execute('''
        INSERT INTO submissions 
        (github_username, exercise_name, result_score, file_content, passed_tests, total_tests, feedback)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', (
        github_username,
        'ex1',
        score,
        file_content,
        passed_tests,
        total_tests,
        '\n'.join(feedback)
    ))
    
    conn.commit()
    conn.close()
    
    # Print summary for logs
    print(f"Evaluation complete for {github_username}")
    print(f"Score: {score}/100")
    print(f"Tests passed: {passed_tests}/{total_tests}")
    for line in feedback:
        print(f"  {line}")
    
    return score

def main():
    if len(sys.argv) != 4:
        print("ERROR: Usage: python evaluator.py <submission_file> <database> <github_username>")
        print(f"Got {len(sys.argv)-1} args: {sys.argv[1:]}")
        sys.exit(1)
    
    file_path = sys.argv[1]
    database_path_github = sys.argv[2]
    github_username = sys.argv[3]
    database_path = "/data/results.db"

    print (f'file_path: {file_path}')
    print (f"Using database at: {database_path_github}, local: {database_path}  ")
    print (f'github_username: {github_username}')

    
    if not Path(file_path).exists():
        print(f"ERROR: File not found: {file_path}")
        sys.exit(1)
    
    try:
        score = evaluate_submission(file_path, database_path, github_username)
        if score >= 0:
            print("Evaluation succeeded.")
            sys.exit(0)
        else:
            print("ERROR: Evaluation failed with negative score.")
            sys.exit(1)
    except Exception as e:
        print(f"ERROR in evaluation: {type(e).__name__}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()