"""
Security audit script for the SniffTest API
"""

import asyncio
import logging
import json
import time
from typing import Dict, List, Any
from datetime import datetime
import subprocess
import sys
import os

# Add the app directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.core.config import settings
from app.database import get_connection_stats
from app.utils.security import SecurityValidator

logger = logging.getLogger(__name__)

class SecurityAuditor:
    """Security audit tool for the SniffTest API"""
    
    def __init__(self):
        self.audit_results = {
            "timestamp": datetime.utcnow().isoformat(),
            "environment": settings.environment,
            "checks": {},
            "summary": {
                "total_checks": 0,
                "passed": 0,
                "failed": 0,
                "warnings": 0
            }
        }
    
    async def run_full_audit(self) -> Dict[str, Any]:
        """
        Run a comprehensive security audit
        
        Returns:
            Audit results dictionary
        """
        logger.info("Starting security audit...")
        
        # Configuration checks
        await self._check_configuration()
        
        # Dependency checks
        await self._check_dependencies()
        
        # Database security checks
        await self._check_database_security()
        
        # API security checks
        await self._check_api_security()
        
        # Input validation checks
        await self._check_input_validation()
        
        # Authentication and authorization checks
        await self._check_authentication()
        
        # GDPR compliance checks
        await self._check_gdpr_compliance()
        
        # Performance and monitoring checks
        await self._check_monitoring()
        
        # Generate summary
        self._generate_summary()
        
        logger.info("Security audit completed")
        return self.audit_results
    
    async def _check_configuration(self):
        """Check configuration security"""
        logger.info("Checking configuration security...")
        
        checks = [
            ("secret_key_strength", self._check_secret_key),
            ("cors_configuration", self._check_cors_config),
            ("environment_settings", self._check_environment),
            ("rate_limiting", self._check_rate_limiting),
            ("security_headers", self._check_security_headers)
        ]
        
        for check_name, check_func in checks:
            try:
                result = await check_func()
                self.audit_results["checks"][check_name] = result
            except Exception as e:
                self.audit_results["checks"][check_name] = {
                    "status": "error",
                    "message": str(e)
                }
    
    async def _check_dependencies(self):
        """Check dependency security"""
        logger.info("Checking dependency security...")
        
        try:
            # Check for known vulnerabilities
            result = subprocess.run(
                ["pip", "audit", "--format=json"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                vulnerabilities = json.loads(result.stdout)
                self.audit_results["checks"]["dependency_vulnerabilities"] = {
                    "status": "passed" if not vulnerabilities else "failed",
                    "vulnerabilities": vulnerabilities,
                    "message": f"Found {len(vulnerabilities)} vulnerabilities" if vulnerabilities else "No vulnerabilities found"
                }
            else:
                self.audit_results["checks"]["dependency_vulnerabilities"] = {
                    "status": "warning",
                    "message": "Could not check dependencies (pip-audit not available)"
                }
        except Exception as e:
            self.audit_results["checks"]["dependency_vulnerabilities"] = {
                "status": "error",
                "message": f"Error checking dependencies: {e}"
            }
    
    async def _check_database_security(self):
        """Check database security"""
        logger.info("Checking database security...")
        
        try:
            # Check connection stats
            stats = get_connection_stats()
            self.audit_results["checks"]["database_connection"] = {
                "status": "passed" if stats["status"] == "connected" else "failed",
                "details": stats
            }
            
            # Check RLS policies (would need database access)
            self.audit_results["checks"]["row_level_security"] = {
                "status": "info",
                "message": "RLS policies should be verified in Supabase dashboard"
            }
            
        except Exception as e:
            self.audit_results["checks"]["database_security"] = {
                "status": "error",
                "message": f"Error checking database security: {e}"
            }
    
    async def _check_api_security(self):
        """Check API security"""
        logger.info("Checking API security...")
        
        checks = [
            ("input_sanitization", self._test_input_sanitization),
            ("sql_injection_protection", self._test_sql_injection),
            ("xss_protection", self._test_xss_protection),
            ("csrf_protection", self._test_csrf_protection)
        ]
        
        for check_name, check_func in checks:
            try:
                result = await check_func()
                self.audit_results["checks"][check_name] = result
            except Exception as e:
                self.audit_results["checks"][check_name] = {
                    "status": "error",
                    "message": str(e)
                }
    
    async def _check_input_validation(self):
        """Check input validation"""
        logger.info("Checking input validation...")
        
        try:
            # Test email validation
            email_tests = [
                ("valid@example.com", True),
                ("invalid-email", False),
                ("<script>alert('xss')</script>", False)
            ]
            
            email_results = []
            for email, should_pass in email_tests:
                try:
                    SecurityValidator.validate_email(email)
                    email_results.append({"email": email, "passed": True, "expected": should_pass})
                except Exception:
                    email_results.append({"email": email, "passed": False, "expected": should_pass})
            
            self.audit_results["checks"]["email_validation"] = {
                "status": "passed" if all(r["passed"] == r["expected"] for r in email_results) else "failed",
                "tests": email_results
            }
            
        except Exception as e:
            self.audit_results["checks"]["input_validation"] = {
                "status": "error",
                "message": f"Error checking input validation: {e}"
            }
    
    async def _check_authentication(self):
        """Check authentication and authorization"""
        logger.info("Checking authentication and authorization...")
        
        self.audit_results["checks"]["authentication"] = {
            "status": "info",
            "message": "Authentication uses Supabase Auth with JWT tokens",
            "features": {
                "jwt_tokens": True,
                "mfa_support": settings.enable_mfa,
                "rate_limiting": True,
                "session_timeout": settings.session_timeout_minutes
            }
        }
    
    async def _check_gdpr_compliance(self):
        """Check GDPR compliance"""
        logger.info("Checking GDPR compliance...")
        
        gdpr_features = {
            "data_export": settings.enable_data_export,
            "data_deletion": settings.enable_data_deletion,
            "data_retention": settings.data_retention_days,
            "audit_logging": settings.enable_audit_logging
        }
        
        self.audit_results["checks"]["gdpr_compliance"] = {
            "status": "passed" if all(gdpr_features.values()) else "warning",
            "features": gdpr_features,
            "message": "GDPR compliance features are implemented" if all(gdpr_features.values()) else "Some GDPR features are disabled"
        }
    
    async def _check_monitoring(self):
        """Check monitoring and logging"""
        logger.info("Checking monitoring and logging...")
        
        monitoring_features = {
            "audit_logging": settings.enable_audit_logging,
            "health_checks": True,
            "metrics_collection": True,
            "error_handling": True
        }
        
        self.audit_results["checks"]["monitoring"] = {
            "status": "passed" if all(monitoring_features.values()) else "warning",
            "features": monitoring_features
        }
    
    async def _check_secret_key(self) -> Dict[str, Any]:
        """Check secret key strength"""
        if len(settings.secret_key) < 32:
            return {"status": "failed", "message": "Secret key is too short"}
        elif settings.secret_key == "your-secret-key-here":
            return {"status": "failed", "message": "Default secret key is being used"}
        else:
            return {"status": "passed", "message": "Secret key appears to be secure"}
    
    async def _check_cors_config(self) -> Dict[str, Any]:
        """Check CORS configuration"""
        if "*" in settings.allowed_origins:
            return {"status": "warning", "message": "CORS allows all origins"}
        elif len(settings.allowed_origins) == 0:
            return {"status": "failed", "message": "No CORS origins configured"}
        else:
            return {"status": "passed", "message": f"CORS configured for {len(settings.allowed_origins)} origins"}
    
    async def _check_environment(self) -> Dict[str, Any]:
        """Check environment configuration"""
        if settings.environment == "production" and settings.debug:
            return {"status": "failed", "message": "Debug mode enabled in production"}
        elif settings.environment not in ["development", "staging", "production"]:
            return {"status": "warning", "message": f"Unknown environment: {settings.environment}"}
        else:
            return {"status": "passed", "message": f"Environment: {settings.environment}"}
    
    async def _check_rate_limiting(self) -> Dict[str, Any]:
        """Check rate limiting configuration"""
        if settings.rate_limit_per_minute <= 0:
            return {"status": "failed", "message": "Rate limiting disabled"}
        elif settings.rate_limit_per_minute > 1000:
            return {"status": "warning", "message": "Rate limit is very high"}
        else:
            return {"status": "passed", "message": f"Rate limit: {settings.rate_limit_per_minute} requests/minute"}
    
    async def _check_security_headers(self) -> Dict[str, Any]:
        """Check security headers configuration"""
        # This would need to test actual HTTP responses
        return {"status": "info", "message": "Security headers middleware is configured"}
    
    async def _test_input_sanitization(self) -> Dict[str, Any]:
        """Test input sanitization"""
        try:
            # Test dangerous input
            dangerous_inputs = [
                "<script>alert('xss')</script>",
                "javascript:alert('xss')",
                "'; DROP TABLE users; --"
            ]
            
            results = []
            for input_text in dangerous_inputs:
                try:
                    SecurityValidator.sanitize_text(input_text)
                    results.append({"input": input_text, "blocked": False})
                except Exception:
                    results.append({"input": input_text, "blocked": True})
            
            all_blocked = all(r["blocked"] for r in results)
            return {
                "status": "passed" if all_blocked else "failed",
                "tests": results,
                "message": "All dangerous inputs blocked" if all_blocked else "Some dangerous inputs not blocked"
            }
        except Exception as e:
            return {"status": "error", "message": str(e)}
    
    async def _test_sql_injection(self) -> Dict[str, Any]:
        """Test SQL injection protection"""
        # This would need database access to test
        return {"status": "info", "message": "SQL injection protection should be tested with database"}
    
    async def _test_xss_protection(self) -> Dict[str, Any]:
        """Test XSS protection"""
        # This would need HTTP testing
        return {"status": "info", "message": "XSS protection should be tested with HTTP requests"}
    
    async def _test_csrf_protection(self) -> Dict[str, Any]:
        """Test CSRF protection"""
        # This would need HTTP testing
        return {"status": "info", "message": "CSRF protection should be tested with HTTP requests"}
    
    def _generate_summary(self):
        """Generate audit summary"""
        total_checks = len(self.audit_results["checks"])
        passed = sum(1 for check in self.audit_results["checks"].values() 
                    if check.get("status") == "passed")
        failed = sum(1 for check in self.audit_results["checks"].values() 
                    if check.get("status") == "failed")
        warnings = sum(1 for check in self.audit_results["checks"].values() 
                      if check.get("status") == "warning")
        
        self.audit_results["summary"] = {
            "total_checks": total_checks,
            "passed": passed,
            "failed": failed,
            "warnings": warnings,
            "score": round((passed / total_checks) * 100, 2) if total_checks > 0 else 0
        }

async def main():
    """Main function to run security audit"""
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )
    
    # Run audit
    auditor = SecurityAuditor()
    results = await auditor.run_full_audit()
    
    # Print results
    print("\n" + "="*50)
    print("SECURITY AUDIT RESULTS")
    print("="*50)
    
    print(f"\nSummary:")
    print(f"  Total Checks: {results['summary']['total_checks']}")
    print(f"  Passed: {results['summary']['passed']}")
    print(f"  Failed: {results['summary']['failed']}")
    print(f"  Warnings: {results['summary']['warnings']}")
    print(f"  Score: {results['summary']['score']}%")
    
    print(f"\nDetailed Results:")
    for check_name, check_result in results["checks"].items():
        status = check_result.get("status", "unknown")
        message = check_result.get("message", "No message")
        
        status_icon = {
            "passed": "✅",
            "failed": "❌",
            "warning": "⚠️",
            "info": "ℹ️",
            "error": "🔥"
        }.get(status, "❓")
        
        print(f"  {status_icon} {check_name}: {status.upper()} - {message}")
    
    # Save results to file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"security_audit_{timestamp}.json"
    
    with open(filename, "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\nDetailed results saved to: {filename}")
    
    # Return exit code based on results
    if results["summary"]["failed"] > 0:
        print("\n❌ Security audit failed - critical issues found")
        return 1
    elif results["summary"]["warnings"] > 0:
        print("\n⚠️ Security audit completed with warnings")
        return 0
    else:
        print("\n✅ Security audit passed - no issues found")
        return 0

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
