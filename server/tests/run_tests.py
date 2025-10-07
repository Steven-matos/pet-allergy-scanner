#!/usr/bin/env python3
"""
Test Runner for SniffTest API

Organized test runner that can execute tests by category or all tests.
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path

# Add the server directory to Python path
sys.path.insert(0, str(Path(__file__).parent.parent))

def run_security_tests():
    """Run security-related tests"""
    print("🔒 Running Security Tests...")
    return subprocess.run([
        "python", "-m", "pytest", 
        "tests/security/", 
        "-v", "--tb=short"
    ], cwd=Path(__file__).parent.parent)

def run_nutrition_tests():
    """Run nutrition-related tests"""
    print("🥗 Running Nutrition Tests...")
    return subprocess.run([
        "python", "-m", "pytest", 
        "tests/nutrition/", 
        "-v", "--tb=short"
    ], cwd=Path(__file__).parent.parent)

def run_notification_tests():
    """Run notification-related tests"""
    print("📱 Running Notification Tests...")
    return subprocess.run([
        "python", "-m", "pytest", 
        "tests/notifications/", 
        "-v", "--tb=short"
    ], cwd=Path(__file__).parent.parent)

def run_database_tests():
    """Run database-related tests"""
    print("🗄️ Running Database Tests...")
    return subprocess.run([
        "python", "-m", "pytest", 
        "tests/database/", 
        "-v", "--tb=short"
    ], cwd=Path(__file__).parent.parent)

def run_unit_tests():
    """Run unit tests"""
    print("🧪 Running Unit Tests...")
    return subprocess.run([
        "python", "-m", "pytest", 
        "tests/unit/", 
        "-v", "--tb=short"
    ], cwd=Path(__file__).parent.parent)

def run_integration_tests():
    """Run integration tests"""
    print("🔗 Running Integration Tests...")
    return subprocess.run([
        "python", "-m", "pytest", 
        "tests/integration/", 
        "-v", "--tb=short"
    ], cwd=Path(__file__).parent.parent)

def run_all_tests():
    """Run all tests"""
    print("🚀 Running All Tests...")
    return subprocess.run([
        "python", "-m", "pytest", 
        "tests/", 
        "-v", "--tb=short"
    ], cwd=Path(__file__).parent.parent)

def main():
    """Main test runner function"""
    parser = argparse.ArgumentParser(description="SniffTest API Test Runner")
    parser.add_argument(
        "category", 
        nargs="?", 
        choices=["security", "nutrition", "notifications", "database", "unit", "integration", "all"],
        default="all",
        help="Test category to run (default: all)"
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🧪 SniffTest API Test Runner")
    print("=" * 60)
    print()
    
    # Run tests based on category
    if args.category == "security":
        result = run_security_tests()
    elif args.category == "nutrition":
        result = run_nutrition_tests()
    elif args.category == "notifications":
        result = run_notification_tests()
    elif args.category == "database":
        result = run_database_tests()
    elif args.category == "unit":
        result = run_unit_tests()
    elif args.category == "integration":
        result = run_integration_tests()
    else:  # all
        result = run_all_tests()
    
    print()
    if result.returncode == 0:
        print("✅ All tests passed!")
    else:
        print("❌ Some tests failed!")
    
    return result.returncode

if __name__ == "__main__":
    sys.exit(main())
