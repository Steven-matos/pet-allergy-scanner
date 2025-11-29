"""
Monitoring and alerting service
"""

from app.utils.logging_config import get_logger
import time
import json
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from app.shared.services.datetime_service import DateTimeService
from app.shared.services.database_operation_service import DatabaseOperationService
from app.core.config import settings
from app.core.database import get_supabase_client

logger = get_logger(__name__)

class MonitoringService:
    """Service for monitoring and alerting"""
    
    def __init__(self):
        self.supabase = get_supabase_client()
        self.metrics = {}
        self.alerts = []
    
    def log_security_event(self, event_type: str, user_id: Optional[str], 
                          details: Dict[str, Any], severity: str = "medium"):
        """
        Log security-related events
        
        Args:
            event_type: Type of security event
            user_id: User ID if applicable
            details: Event details
            severity: Event severity (low, medium, high, critical)
        """
        try:
            event_data = {
                "timestamp": DateTimeService.now_iso(),
                "event_type": event_type,
                "user_id": user_id,
                "severity": severity,
                "details": details,
                "environment": settings.environment
            }
            
            # Log to file
            logger.critical(f"Security event: {json.dumps(event_data)}")
            
            # Note: Database logging skipped for fire-and-forget security events
            # to avoid blocking. Critical events are logged to file and alerts sent.
            
            # Check if alert is needed
            if severity in ["high", "critical"]:
                self._send_alert(event_data)
                
        except Exception as e:
            logger.error(f"Failed to log security event: {e}")
    
    def log_performance_metric(self, metric_name: str, value: float, 
                              tags: Optional[Dict[str, str]] = None):
        """
        Log performance metrics
        
        Args:
            metric_name: Name of the metric
            value: Metric value
            tags: Optional tags for the metric
        """
        try:
            metric_data = {
                "timestamp": DateTimeService.now_iso(),
                "metric_name": metric_name,
                "value": value,
                "tags": tags or {},
                "environment": settings.environment
            }
            
            # Store in memory for quick access
            if metric_name not in self.metrics:
                self.metrics[metric_name] = []
            
            self.metrics[metric_name].append(metric_data)
            
            # Keep only last 1000 entries
            if len(self.metrics[metric_name]) > 1000:
                self.metrics[metric_name] = self.metrics[metric_name][-1000:]
            
            # Log to file
            
        except Exception as e:
            logger.error(f"Failed to log performance metric: {e}")
    
    def log_user_activity(self, user_id: str, activity_type: str, 
                         details: Dict[str, Any]):
        """
        Log user activity for audit purposes
        
        Args:
            user_id: User ID
            activity_type: Type of activity
            details: Activity details
        """
        try:
            activity_data = {
                "timestamp": DateTimeService.now_iso(),
                "user_id": user_id,
                "activity_type": activity_type,
                "details": details,
                "environment": settings.environment
            }
            
            # Log to file
            
            # Note: Database logging skipped for fire-and-forget user activities
            # to avoid blocking. Activity logging focuses on file-based audit trail.
                
        except Exception as e:
            logger.error(f"Failed to log user activity: {e}")
    
    def get_metrics_summary(self, hours: int = 24) -> Dict[str, Any]:
        """
        Get metrics summary for the last N hours
        
        Args:
            hours: Number of hours to look back
            
        Returns:
            Metrics summary
        """
        try:
            cutoff_time = DateTimeService.now() - timedelta(hours=hours)
            
            summary = {
                "period_hours": hours,
                "metrics": {},
                "alerts": [],
                "timestamp": DateTimeService.now_iso()
            }
            
            # Calculate metrics
            for metric_name, data in self.metrics.items():
                recent_data = [
                    d for d in data 
                    if datetime.fromisoformat(d["timestamp"]) > cutoff_time
                ]
                
                if recent_data:
                    values = [d["value"] for d in recent_data]
                    summary["metrics"][metric_name] = {
                        "count": len(values),
                        "min": min(values),
                        "max": max(values),
                        "avg": sum(values) / len(values),
                        "latest": values[-1]
                    }
            
            # Get recent alerts
            summary["alerts"] = [
                alert for alert in self.alerts
                if datetime.fromisoformat(alert["timestamp"]) > cutoff_time
            ]
            
            return summary
            
        except Exception as e:
            logger.error(f"Failed to get metrics summary: {e}")
            return {"error": str(e)}
    
    def check_health(self) -> Dict[str, Any]:
        """
        Check system health
        
        Returns:
            Health status compatible with iOS HealthStatus model
            Expected format:
            {
                "status": "healthy|degraded|unhealthy",
                "version": "1.0.0",
                "environment": "production",
                "debug_mode": false,
                "database": {
                    "status": "healthy",
                    "connection_count": 10,
                    "response_time": 0.05,
                    "last_check": "2025-11-09T12:00:00Z"
                },
                "timestamp": 1699536000.0
            }
        """
        try:
            from app.core.config import settings
            import time
            
            health_status = {
                "status": "healthy",
                "version": settings.api_version,
                "environment": settings.environment,
                "debug_mode": settings.debug,
                "timestamp": time.time()
            }
            
            # Check database connection
            db_status = "healthy"
            db_response_time = 0.0
            connection_count = settings.database_pool_size
            
            try:
                start_time = time.time()
                self.supabase.table("users").select("id").limit(1).execute()
                db_response_time = time.time() - start_time
                
                if db_response_time > 1.0:
                    health_status["status"] = "degraded"
                    
            except Exception as e:
                db_status = "unhealthy"
                health_status["status"] = "unhealthy"
                logger.error(f"Database health check failed: {e}")
            
            health_status["database"] = {
                "status": db_status,
                "connection_count": connection_count,
                "response_time": round(db_response_time, 3),
                "last_check": DateTimeService.now_iso() + "Z"
            }
            
            # Check memory usage (optional, won't fail if psutil not available)
            try:
                import psutil
                memory_percent = psutil.virtual_memory().percent
                
                if memory_percent > 90:
                    health_status["status"] = "degraded"
            except ImportError:
                pass
            
            # Check disk usage (optional)
            try:
                import psutil
                disk_percent = psutil.disk_usage('/').percent
                
                if disk_percent > 90:
                    health_status["status"] = "degraded"
            except ImportError:
                pass
            
            return health_status
            
        except Exception as e:
            logger.error(f"Failed to check health: {e}")
            from app.core.config import settings
            import time
            
            return {
                "status": "unhealthy",
                "version": settings.api_version,
                "environment": settings.environment,
                "debug_mode": settings.debug,
                "database": {
                    "status": "unhealthy",
                    "connection_count": 0,
                    "response_time": 0.0,
                    "last_check": DateTimeService.now_iso() + "Z"
                },
                "timestamp": time.time()
            }
    
    def _send_alert(self, event_data: Dict[str, Any]):
        """
        Send alert for critical events
        
        Args:
            event_data: Event data
        """
        try:
            alert = {
                "timestamp": DateTimeService.now_iso(),
                "event": event_data,
                "sent": False
            }
            
            # Add to alerts list
            self.alerts.append(alert)
            
            # Keep only last 100 alerts
            if len(self.alerts) > 100:
                self.alerts = self.alerts[-100:]
            
            # Log alert
            logger.critical(f"SECURITY ALERT: {json.dumps(alert)}")
            
            # In production, you would send to external alerting service
            # For now, just log it
            
        except Exception as e:
            logger.error(f"Failed to send alert: {e}")
    
    def cleanup_old_data(self, days: int = 30):
        """
        Clean up old monitoring data
        
        Args:
            days: Number of days to keep
        """
        try:
            cutoff_time = DateTimeService.now() - timedelta(days=days)
            
            # Clean up metrics
            for metric_name in self.metrics:
                self.metrics[metric_name] = [
                    d for d in self.metrics[metric_name]
                    if datetime.fromisoformat(d["timestamp"]) > cutoff_time
                ]
            
            # Clean up alerts
            self.alerts = [
                alert for alert in self.alerts
                if datetime.fromisoformat(alert["timestamp"]) > cutoff_time
            ]
            
            
        except Exception as e:
            logger.error(f"Failed to cleanup old data: {e}")
