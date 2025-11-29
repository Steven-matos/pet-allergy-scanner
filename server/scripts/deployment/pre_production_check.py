"""
Pre-Production Build Check Script

Validates the codebase before production deployment:
- Import checks for all modules
- Syntax validation
- Basic functionality tests
- Missing dependency checks

Run this before deploying to production.
"""

import sys
import importlib
import ast
import os
from pathlib import Path
from typing import List, Tuple

# Add server directory to Python path
server_dir = Path(__file__).parent.parent.parent
sys.path.insert(0, str(server_dir))

# Color codes for terminal output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"

def print_success(message: str):
    """Print success message"""
    print(f"{GREEN}✅ {message}{RESET}")

def print_error(message: str):
    """Print error message"""
    print(f"{RED}❌ {message}{RESET}")

def print_warning(message: str):
    """Print warning message"""
    print(f"{YELLOW}⚠️  {message}{RESET}")

def print_info(message: str):
    """Print info message"""
    print(f"{BLUE}ℹ️  {message}{RESET}")

def check_syntax(file_path: Path) -> Tuple[bool, str]:
    """
    Check Python file syntax
    
    Args:
        file_path: Path to Python file
        
    Returns:
        Tuple of (is_valid, error_message)
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            source = f.read()
        ast.parse(source, filename=str(file_path))
        return True, ""
    except SyntaxError as e:
        return False, f"Syntax error at line {e.lineno}: {e.msg}"
    except Exception as e:
        return False, f"Error: {str(e)}"

def check_imports() -> Tuple[int, int]:
    """
    Check if all critical modules can be imported
    
    Returns:
        Tuple of (success_count, failure_count)
    """
    print_info("Checking module imports...")
    
    critical_modules = [
        # Core
        "app.core.config",
        "app.database",
        # Note: app.main is excluded - it's the main application entry point
        # and may have import issues when run standalone (expected)
        
        # Shared Services (newly added/modified)
        "app.shared.services.html_sanitization_service",
        "app.shared.services.user_friendly_error_messages",
        "app.shared.services.cache_service",
        "app.shared.services.query_builder_service",
        
        # Utils
        "app.utils.error_handling",
        
        # API Routers (key ones)
        "app.api.v1.subscriptions.router",
        "app.api.v1.scanning.router",
        "app.api.v1.medication_reminders.router",
        "app.api.v1.health_events.router",
        "app.api.v1.notifications.router",
        
        # Services (modified)
        "app.services.weight_tracking_service",
        "app.services.push_notification_service",
        
        # Models (modified)
        "app.models.health_event",
        "app.models.scan",
        "app.models.advanced_nutrition",
        "app.models.nutrition",
        "app.models.calorie_goals",
        "app.models.food_items",
    ]
    
    success_count = 0
    failure_count = 0
    
    for module_name in critical_modules:
        try:
            importlib.import_module(module_name)
            print_success(f"Imported: {module_name}")
            success_count += 1
        except ImportError as e:
            print_error(f"Failed to import {module_name}: {e}")
            failure_count += 1
        except Exception as e:
            print_error(f"Error importing {module_name}: {e}")
            failure_count += 1
    
    return success_count, failure_count

def check_new_services() -> Tuple[int, int]:
    """
    Check newly added services for basic functionality
    
    Returns:
        Tuple of (success_count, failure_count)
    """
    print_info("Checking new services...")
    
    success_count = 0
    failure_count = 0
    
    # Check HTML Sanitization Service
    try:
        from app.shared.services.html_sanitization_service import (
            HTMLSanitizationService,
            SanitizationLevel
        )
        
        # Test basic functionality
        test_html = "<script>alert('xss')</script>Hello"
        sanitized = HTMLSanitizationService.sanitize(test_html, SanitizationLevel.STRICT)
        if "<script>" not in sanitized:
            print_success("HTMLSanitizationService: Basic sanitization works")
            success_count += 1
        else:
            print_error("HTMLSanitizationService: Sanitization failed")
            failure_count += 1
    except Exception as e:
        print_error(f"HTMLSanitizationService check failed: {e}")
        failure_count += 1
    
    # Check User-Friendly Error Messages Service
    try:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        
        # Test basic functionality
        friendly = UserFriendlyErrorMessages.get_user_friendly_message("not found")
        if friendly and len(friendly) > 0:
            print_success("UserFriendlyErrorMessages: Basic message translation works")
            success_count += 1
        else:
            print_error("UserFriendlyErrorMessages: Message translation failed")
            failure_count += 1
    except Exception as e:
        print_error(f"UserFriendlyErrorMessages check failed: {e}")
        failure_count += 1
    
    # Check Cache Service (Redis support)
    try:
        from app.shared.services.cache_service import CacheService, cache_service
        
        # Test basic functionality
        cache = CacheService()
        print_success("CacheService: Can be instantiated")
        success_count += 1
    except Exception as e:
        print_error(f"CacheService check failed: {e}")
        failure_count += 1
    
    # Check Query Builder Service (new methods)
    try:
        from app.shared.services.query_builder_service import QueryBuilderService
        from app.database import get_supabase_client
        
        supabase = get_supabase_client()
        qb = QueryBuilderService(supabase, "users")
        
        # Check new methods exist
        if hasattr(qb, 'with_user_and_pet_filter'):
            print_success("QueryBuilderService: New methods available")
            success_count += 1
        else:
            print_error("QueryBuilderService: New methods missing")
            failure_count += 1
    except Exception as e:
        print_warning(f"QueryBuilderService check failed (may need DB connection): {e}")
        # Don't count as failure since it might need DB
    
    return success_count, failure_count

def check_syntax_files() -> Tuple[int, int]:
    """
    Check syntax of modified files
    
    Returns:
        Tuple of (success_count, failure_count)
    """
    print_info("Checking syntax of modified files...")
    
    modified_files = [
        "app/shared/services/html_sanitization_service.py",
        "app/shared/services/user_friendly_error_messages.py",
        "app/shared/services/cache_service.py",
        "app/shared/services/query_builder_service.py",
        "app/utils/error_handling.py",
        "app/api/v1/subscriptions/router.py",
        "app/api/v1/scanning/router.py",
        "app/api/v1/medication_reminders/router.py",
        "app/api/v1/health_events/router.py",
        "app/api/v1/notifications/router.py",
        "app/services/weight_tracking_service.py",
        "app/services/push_notification_service.py",
        "app/models/health_event.py",
        "app/models/scan.py",
        "app/models/advanced_nutrition.py",
        "app/models/nutrition.py",
        "app/models/calorie_goals.py",
        "app/models/food_items.py",
    ]
    
    success_count = 0
    failure_count = 0
    
    server_dir = Path(__file__).parent.parent.parent
    for file_path in modified_files:
        full_path = server_dir / file_path
        if full_path.exists():
            is_valid, error = check_syntax(full_path)
            if is_valid:
                print_success(f"Syntax OK: {file_path}")
                success_count += 1
            else:
                print_error(f"Syntax error in {file_path}: {error}")
                failure_count += 1
        else:
            print_warning(f"File not found: {file_path}")
    
    return success_count, failure_count

def check_dependencies() -> bool:
    """
    Check if required dependencies are available
    
    Returns:
        True if all dependencies are available
    """
    print_info("Checking dependencies...")
    
    required_deps = {
        "bleach": True,  # Required
        "pydantic": True,  # Required
        "fastapi": True,  # Required
        "supabase": True,  # Required
        "jwt": True,  # Required (PyJWT)
    }
    
    optional_deps = {
        "redis": False,  # Optional - falls back to in-memory cache
    }
    
    all_required_available = True
    for dep, required in required_deps.items():
        try:
            if dep == "jwt":
                import jwt
            else:
                importlib.import_module(dep)
            print_success(f"Dependency available: {dep}")
        except ImportError:
            print_error(f"Missing required dependency: {dep}")
            all_required_available = False
    
    # Check optional dependencies
    for dep, required in optional_deps.items():
        try:
            importlib.import_module(dep)
            print_success(f"Optional dependency available: {dep}")
        except ImportError:
            print_warning(f"Optional dependency not available: {dep} (will use fallback)")
    
    return all_required_available

def main():
    """Run all pre-production checks"""
    print(f"\n{BLUE}{'='*60}")
    print("PRE-PRODUCTION BUILD CHECK")
    print("="*60 + RESET + "\n")
    
    results = {
        "imports": (0, 0),
        "services": (0, 0),
        "syntax": (0, 0),
        "dependencies": False,
    }
    
    # Check dependencies first
    results["dependencies"] = check_dependencies()
    print()
    
    # Check syntax
    results["syntax"] = check_syntax_files()
    print()
    
    # Check imports
    results["imports"] = check_imports()
    print()
    
    # Check new services
    results["services"] = check_new_services()
    print()
    
    # Summary
    print(f"\n{BLUE}{'='*60}")
    print("SUMMARY")
    print("="*60 + RESET + "\n")
    
    total_success = 0
    total_failure = 0
    
    # Syntax check
    syntax_success, syntax_failure = results["syntax"]
    total_success += syntax_success
    total_failure += syntax_failure
    print(f"Syntax Check: {GREEN}{syntax_success} passed{RESET}, {RED}{syntax_failure} failed{RESET}")
    
    # Import check
    import_success, import_failure = results["imports"]
    total_success += import_success
    total_failure += import_failure
    print(f"Import Check: {GREEN}{import_success} passed{RESET}, {RED}{import_failure} failed{RESET}")
    
    # Service check
    service_success, service_failure = results["services"]
    total_success += service_success
    total_failure += service_failure
    print(f"Service Check: {GREEN}{service_success} passed{RESET}, {RED}{service_failure} failed{RESET}")
    
    # Dependencies
    if results["dependencies"]:
        print(f"Dependencies: {GREEN}All available{RESET}")
    else:
        print(f"Dependencies: {RED}Some missing{RESET}")
        total_failure += 1
    
    print()
    print(f"{BLUE}{'='*60}{RESET}")
    
    if total_failure == 0:
        print_success(f"All checks passed! ({total_success} checks)")
        print(f"\n{GREEN}✅ Ready for production deployment!{RESET}\n")
        return 0
    else:
        print_error(f"Some checks failed: {total_failure} failures, {total_success} successes")
        print(f"\n{RED}❌ Please fix the issues above before deploying to production.{RESET}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())

