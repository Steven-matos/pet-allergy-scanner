"""
Security utility functions for input validation and sanitization
"""

import re
import html
import bleach
import logging
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from app.core.config import settings

logger = logging.getLogger(__name__)

class SecurityValidator:
    """Security validation and sanitization utilities"""
    
    # Common dangerous patterns
    DANGEROUS_PATTERNS = [
        r'<script[^>]*>.*?</script>',
        r'javascript:',
        r'vbscript:',
        r'onload\s*=',
        r'onerror\s*=',
        r'onclick\s*=',
        r'eval\s*\(',
        r'expression\s*\(',
        r'url\s*\(',
        r'@import',
        r'behavior\s*:',
        r'-moz-binding',
        r'<iframe[^>]*>',
        r'<object[^>]*>',
        r'<embed[^>]*>',
        r'<link[^>]*>',
        r'<meta[^>]*>',
        r'<style[^>]*>',
        r'<form[^>]*>',
        r'<input[^>]*>',
        r'<textarea[^>]*>',
        r'<select[^>]*>',
        r'<button[^>]*>',
        r'<a[^>]*>',
        r'<img[^>]*>',
        r'<video[^>]*>',
        r'<audio[^>]*>',
        r'<source[^>]*>',
        r'<track[^>]*>',
        r'<canvas[^>]*>',
        r'<svg[^>]*>',
        r'<math[^>]*>',
        r'<applet[^>]*>',
        r'<param[^>]*>',
        r'<base[^>]*>',
        r'<area[^>]*>',
        r'<map[^>]*>',
        r'<frame[^>]*>',
        r'<frameset[^>]*>',
        r'<noframes[^>]*>',
        r'<noscript[^>]*>',
        r'<details[^>]*>',
        r'<summary[^>]*>',
        r'<dialog[^>]*>',
        r'<menu[^>]*>',
        r'<menuitem[^>]*>',
        r'<command[^>]*>',
        r'<keygen[^>]*>',
        r'<output[^>]*>',
        r'<progress[^>]*>',
        r'<meter[^>]*>',
        r'<datalist[^>]*>',
        r'<optgroup[^>]*>',
        r'<option[^>]*>',
        r'<fieldset[^>]*>',
        r'<legend[^>]*>',
        r'<label[^>]*>',
        r'<datalist[^>]*>',
        r'<keygen[^>]*>',
        r'<output[^>]*>',
        r'<progress[^>]*>',
        r'<meter[^>]*>',
        r'<details[^>]*>',
        r'<summary[^>]*>',
        r'<dialog[^>]*>',
        r'<menu[^>]*>',
        r'<menuitem[^>]*>',
        r'<command[^>]*>',
        r'<keygen[^>]*>',
        r'<output[^>]*>',
        r'<progress[^>]*>',
        r'<meter[^>]*>',
        r'<datalist[^>]*>',
        r'<optgroup[^>]*>',
        r'<option[^>]*>',
        r'<fieldset[^>]*>',
        r'<legend[^>]*>',
        r'<label[^>]*>'
    ]
    
    # SQL injection patterns
    SQL_INJECTION_PATTERNS = [
        r'union\s+select',
        r'select\s+.*\s+from',
        r'insert\s+into',
        r'update\s+.*\s+set',
        r'delete\s+from',
        r'drop\s+table',
        r'create\s+table',
        r'alter\s+table',
        r'exec\s*\(',
        r'execute\s*\(',
        r'sp_',
        r'xp_',
        r'--',
        r'/\*.*\*/',
        r'waitfor\s+delay',
        r'benchmark\s*\(',
        r'sleep\s*\(',
        r'pg_sleep\s*\(',
        r'load_file\s*\(',
        r'into\s+outfile',
        r'into\s+dumpfile',
        r'load\s+data\s+infile',
        r'\.\./',
        r'\.\.\\',
        r'char\s*\(',
        r'ascii\s*\(',
        r'ord\s*\(',
        r'chr\s*\(',
        r'concat\s*\(',
        r'substring\s*\(',
        r'substr\s*\(',
        r'mid\s*\(',
        r'left\s*\(',
        r'right\s*\(',
        r'length\s*\(',
        r'len\s*\(',
        r'count\s*\(',
        r'sum\s*\(',
        r'avg\s*\(',
        r'min\s*\(',
        r'max\s*\(',
        r'group\s+by',
        r'order\s+by',
        r'having\s+',
        r'where\s+',
        r'and\s+',
        r'or\s+',
        r'not\s+',
        r'like\s+',
        r'in\s*\(',
        r'between\s+',
        r'is\s+null',
        r'is\s+not\s+null',
        r'exists\s*\(',
        r'in\s+\(.*select',
        r'not\s+in\s+\(.*select',
        r'exists\s*\(.*select',
        r'not\s+exists\s*\(.*select',
        r'any\s*\(.*select',
        r'all\s*\(.*select',
        r'some\s*\(.*select',
        r'case\s+when',
        r'if\s*\(',
        r'ifnull\s*\(',
        r'coalesce\s*\(',
        r'nullif\s*\(',
        r'cast\s*\(',
        r'convert\s*\(',
        r'str_to_date\s*\(',
        r'date_format\s*\(',
        r'now\s*\(',
        r'curdate\s*\(',
        r'curtime\s*\(',
        r'year\s*\(',
        r'month\s*\(',
        r'day\s*\(',
        r'hour\s*\(',
        r'minute\s*\(',
        r'second\s*\(',
        r'week\s*\(',
        r'dayofweek\s*\(',
        r'dayofyear\s*\(',
        r'weekday\s*\(',
        r'quarter\s*\(',
        r'last_day\s*\(',
        r'makedate\s*\(',
        r'maketime\s*\(',
        r'period_add\s*\(',
        r'period_diff\s*\(',
        r'to_days\s*\(',
        r'to_seconds\s*\(',
        r'from_days\s*\(',
        r'from_unixtime\s*\(',
        r'unix_timestamp\s*\(',
        r'utc_date\s*\(',
        r'utc_time\s*\(',
        r'utc_timestamp\s*\(',
        r'time_to_sec\s*\(',
        r'sec_to_time\s*\(',
        r'time_format\s*\(',
        r'get_format\s*\(',
        r'date_add\s*\(',
        r'date_sub\s*\(',
        r'adddate\s*\(',
        r'subdate\s*\(',
        r'addtime\s*\(',
        r'subtime\s*\(',
        r'datediff\s*\(',
        r'timediff\s*\(',
        r'from_unixtime\s*\(',
        r'unix_timestamp\s*\(',
        r'utc_date\s*\(',
        r'utc_time\s*\(',
        r'utc_timestamp\s*\(',
        r'time_to_sec\s*\(',
        r'sec_to_time\s*\(',
        r'time_format\s*\(',
        r'get_format\s*\(',
        r'date_add\s*\(',
        r'date_sub\s*\(',
        r'adddate\s*\(',
        r'subdate\s*\(',
        r'addtime\s*\(',
        r'subtime\s*\(',
        r'datediff\s*\(',
        r'timediff\s*\('
    ]
    
    @classmethod
    def sanitize_text(cls, text: str, max_length: Optional[int] = None) -> str:
        """
        Sanitize text input by removing dangerous content
        
        Args:
            text: Input text to sanitize
            max_length: Maximum allowed length
            
        Returns:
            Sanitized text
            
        Raises:
            HTTPException: If text contains dangerous content
        """
        if not text:
            return ""
        
        # Check for dangerous patterns
        text_lower = text.lower()
        for pattern in cls.DANGEROUS_PATTERNS:
            if re.search(pattern, text_lower, re.IGNORECASE):
                logger.warning(f"Dangerous pattern detected in text: {pattern}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Input contains potentially dangerous content"
                )
        
        # Check for SQL injection patterns
        for pattern in cls.SQL_INJECTION_PATTERNS:
            if re.search(pattern, text_lower, re.IGNORECASE):
                logger.warning(f"SQL injection pattern detected: {pattern}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Input contains potentially malicious content"
                )
        
        # HTML escape
        sanitized = html.escape(text)
        
        # Remove HTML tags
        sanitized = bleach.clean(sanitized, tags=[], strip=True)
        
        # Limit length
        if max_length and len(sanitized) > max_length:
            sanitized = sanitized[:max_length]
        
        return sanitized.strip()
    
    @classmethod
    def validate_email(cls, email: str) -> str:
        """
        Validate and sanitize email address
        
        Args:
            email: Email address to validate
            
        Returns:
            Sanitized email address
            
        Raises:
            HTTPException: If email is invalid
        """
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is required"
            )
        
        # Basic email validation
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid email format"
            )
        
        # Sanitize email
        sanitized_email = cls.sanitize_text(email.lower(), max_length=254)
        
        return sanitized_email
    
    @classmethod
    def validate_password(cls, password: str) -> str:
        """
        Validate password strength
        
        Args:
            password: Password to validate
            
        Returns:
            Validated password
            
        Raises:
            HTTPException: If password doesn't meet requirements
        """
        if not password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password is required"
            )
        
        if len(password) < 8:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must be at least 8 characters long"
            )
        
        if len(password) > 128:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must be less than 128 characters"
            )
        
        # Check for common weak passwords
        weak_passwords = [
            "password", "123456", "123456789", "qwerty", "abc123",
            "password123", "admin", "letmein", "welcome", "monkey"
        ]
        
        if password.lower() in weak_passwords:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password is too common. Please choose a stronger password"
            )
        
        # Check for at least one uppercase, lowercase, digit, and special character
        if not re.search(r'[A-Z]', password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must contain at least one uppercase letter"
            )
        
        if not re.search(r'[a-z]', password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must contain at least one lowercase letter"
            )
        
        if not re.search(r'\d', password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must contain at least one digit"
            )
        
        if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must contain at least one special character"
            )
        
        return password
    
    @classmethod
    def validate_username(cls, username: str) -> str:
        """
        Validate and sanitize username with profanity filtering
        
        Args:
            username: Username to validate
            
        Returns:
            Sanitized username
            
        Raises:
            HTTPException: If username is invalid or contains inappropriate content
        """
        if not username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username is required"
            )
        
        # Check length
        if len(username) < 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username must be at least 3 characters long"
            )
        
        if len(username) > 30:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username must be less than 30 characters"
            )
        
        # Check for valid characters (alphanumeric, underscore, hyphen)
        if not re.match(r'^[a-zA-Z0-9_-]+$', username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username can only contain letters, numbers, underscores, and hyphens"
            )
        
        # Check if starts with letter or number
        if not re.match(r'^[a-zA-Z0-9]', username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username must start with a letter or number"
            )
        
        # Check for profanity and inappropriate content
        if cls._contains_inappropriate_content(username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username contains inappropriate content. Please choose a different username."
            )
        
        # Check for reserved usernames
        reserved_usernames = [
            'admin', 'administrator', 'root', 'user', 'guest', 'test', 'api',
            'www', 'mail', 'ftp', 'support', 'help', 'info', 'contact',
            'about', 'privacy', 'terms', 'legal', 'security', 'auth',
            'login', 'logout', 'register', 'signup', 'signin', 'signout',
            'password', 'reset', 'forgot', 'verify', 'confirm', 'activate',
            'deactivate', 'delete', 'remove', 'update', 'edit', 'create',
            'new', 'old', 'current', 'previous', 'next', 'first', 'last',
            'home', 'dashboard', 'profile', 'settings', 'account', 'billing',
            'payment', 'subscription', 'premium', 'free', 'basic', 'pro',
            'enterprise', 'business', 'personal', 'private', 'public',
            'system', 'service', 'app', 'application', 'mobile', 'web',
            'desktop', 'client', 'server', 'database', 'api', 'rest',
            'graphql', 'oauth', 'jwt', 'token', 'session', 'cookie',
            'cache', 'redis', 'postgres', 'mysql', 'sqlite', 'mongodb',
            'elasticsearch', 'kibana', 'logstash', 'beats', 'filebeat',
            'metricbeat', 'packetbeat', 'heartbeat', 'auditbeat', 'functionbeat',
            'journalbeat', 'winlogbeat', 'apm', 'rum', 'uptime', 'synthetics',
            'monitoring', 'observability', 'telemetry', 'metrics', 'logs',
            'traces', 'spans', 'events', 'alerts', 'notifications', 'webhooks',
            'integrations', 'plugins', 'extensions', 'modules', 'packages',
            'libraries', 'frameworks', 'tools', 'utilities', 'scripts',
            'automation', 'ci', 'cd', 'deployment', 'infrastructure', 'devops',
            'sre', 'reliability', 'availability', 'scalability', 'performance',
            'optimization', 'tuning', 'profiling', 'debugging', 'testing',
            'qa', 'quality', 'assurance', 'validation', 'verification',
            'compliance', 'governance', 'security', 'privacy', 'gdpr',
            'ccpa', 'hipaa', 'sox', 'pci', 'iso', 'certification', 'audit',
            'logging', 'monitoring', 'alerting', 'incident', 'response',
            'recovery', 'backup', 'restore', 'disaster', 'business',
            'continuity', 'planning', 'strategy', 'roadmap', 'milestone',
            'deliverable', 'artifact', 'documentation', 'wiki', 'knowledge',
            'base', 'repository', 'source', 'code', 'version', 'control',
            'git', 'github', 'gitlab', 'bitbucket', 'azure', 'devops',
            'aws', 'amazon', 'microsoft', 'google', 'cloud', 'azure',
            'gcp', 'google', 'cloud', 'platform', 'heroku', 'netlify',
            'vercel', 'railway', 'render', 'fly', 'io', 'digital', 'ocean',
            'linode', 'vultr', 'scaleway', 'ovh', 'hetzner', 'contabo',
            'ionos', '1and1', 'godaddy', 'namecheap', 'cloudflare',
            'fastly', 'keycdn', 'maxcdn', 'stackpath', 'limelight',
            'akamai', 'amazon', 'cloudfront', 'route53', 's3', 'ec2',
            'lambda', 'api', 'gateway', 'dynamodb', 'rds', 'aurora',
            'redshift', 'elasticache', 'elasticsearch', 'kinesis', 'sns',
            'sqs', 'ses', 'sns', 'pinpoint', 'cognito', 'iam', 'sts',
            'kms', 'secrets', 'manager', 'parameter', 'store', 'ssm',
            'cloudformation', 'cloudwatch', 'xray', 'codepipeline',
            'codebuild', 'codedeploy', 'codestar', 'codepipeline',
            'codecommit', 'codereview', 'codereview', 'codereview',
            'codereview', 'codereview', 'codereview', 'codereview'
        ]
        
        if username.lower() in reserved_usernames:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This username is reserved and cannot be used"
            )
        
        # Sanitize username
        sanitized_username = cls.sanitize_text(username.lower(), max_length=30)
        
        return sanitized_username
    
    @classmethod
    def _contains_inappropriate_content(cls, text: str) -> bool:
        """
        Check if text contains profanity or inappropriate content
        
        Args:
            text: Text to check
            
        Returns:
            True if inappropriate content is found
        """
        text_lower = text.lower()
        
        # Comprehensive profanity and inappropriate content list
        inappropriate_words = [
            # Common profanity
            'fuck', 'fucking', 'fucked', 'fucker', 'fucks', 'fuckin',
            'shit', 'shitting', 'shitted', 'shitter', 'shits', 'shitty',
            'bitch', 'bitches', 'bitching', 'bitched', 'bitchy',
            'ass', 'asses', 'asshole', 'assholes', 'asshat', 'asshats',
            'damn', 'damned', 'damning', 'damnit', 'dammit',
            'hell', 'hells', 'hellish', 'hellishness',
            'crap', 'crappy', 'crappier', 'crappiest',
            'piss', 'pissing', 'pissed', 'pisser', 'pisses', 'pissy',
            'dick', 'dicks', 'dickhead', 'dickheads', 'dickish',
            'cock', 'cocks', 'cocky', 'cockhead', 'cockheads',
            'pussy', 'pussies', 'pussycats', 'pussyfoot',
            'tits', 'titties', 'tit', 'titty', 'titsy',
            'boob', 'boobs', 'boobies', 'booby', 'boobish',
            'whore', 'whores', 'whoring', 'whored', 'whorish',
            'slut', 'sluts', 'slutting', 'slutty', 'sluttish',
            'hoe', 'hoes', 'hoing', 'hoed', 'hoish',
            'nigger', 'niggers', 'nigga', 'niggas', 'niggah', 'niggahs',
            'chink', 'chinks', 'chinky', 'chinkish',
            'kike', 'kikes', 'kikey', 'kikeish',
            'spic', 'spics', 'spicky', 'spickish',
            'wetback', 'wetbacks', 'wetbacky', 'wetbackish',
            'towelhead', 'towelheads', 'towelheady', 'towelheadish',
            'sandnigger', 'sandniggers', 'sandnigga', 'sandniggas',
            'raghead', 'ragheads', 'ragheady', 'ragheadish',
            'terrorist', 'terrorists', 'terroristy', 'terroristish',
            'bomber', 'bombers', 'bombery', 'bomberish',
            'suicide', 'suicides', 'suicidy', 'suicidish',
            'bomb', 'bombs', 'bomby', 'bombish',
            'kill', 'kills', 'killing', 'killed', 'killer', 'killers',
            'murder', 'murders', 'murdering', 'murdered', 'murderer', 'murderers',
            'death', 'deaths', 'deathy', 'deathish',
            'die', 'dies', 'dying', 'died', 'dier', 'diers',
            'dead', 'deads', 'deady', 'deadish',
            'hate', 'hates', 'hating', 'hated', 'hater', 'haters',
            'racist', 'racists', 'racisty', 'racistish',
            'nazi', 'nazis', 'naziy', 'nazish',
            'hitler', 'hitlers', 'hitlery', 'hitlerish',
            'kkk', 'klan', 'klans', 'klany', 'klanish',
            'white', 'whites', 'whitey', 'whiteish',
            'black', 'blacks', 'blacky', 'blackish',
            'yellow', 'yellows', 'yellowy', 'yellowish',
            'red', 'reds', 'reddy', 'reddish',
            'brown', 'browns', 'browny', 'brownish',
            'gay', 'gays', 'gayy', 'gayish',
            'lesbian', 'lesbians', 'lesbiany', 'lesbianish',
            'fag', 'fags', 'faggy', 'faggish',
            'faggot', 'faggots', 'faggoty', 'faggotish',
            'dyke', 'dykes', 'dykey', 'dykish',
            'tranny', 'trannies', 'trannyish', 'trannish',
            'shemale', 'shemales', 'shemaley', 'shemaleish',
            'ladyboy', 'ladyboys', 'ladyboyy', 'ladyboyish',
            'retard', 'retards', 'retarding', 'retarded', 'retarder', 'retarders',
            'retardation', 'retardations', 'retardationy', 'retardationish',
            'idiot', 'idiots', 'idioty', 'idiotish',
            'moron', 'morons', 'morony', 'moronish',
            'stupid', 'stupids', 'stupidy', 'stupidish',
            'dumb', 'dumbs', 'dumby', 'dumbish',
            'retard', 'retards', 'retardy', 'retardish',
            'autistic', 'autistics', 'autisticy', 'autisticish',
            'downs', 'downsy', 'downsish',
            'mongoloid', 'mongoloids', 'mongoloidy', 'mongoloidish',
            'cripple', 'cripples', 'crippling', 'crippled', 'crippler', 'cripplers',
            'handicap', 'handicaps', 'handicapping', 'handicapped', 'handicapper', 'handicappers',
            'disabled', 'disableds', 'disabledy', 'disabledish',
            'blind', 'blinds', 'blindy', 'blindish',
            'deaf', 'deafs', 'deafy', 'deafish',
            'mute', 'mutes', 'muty', 'muteish',
            'dwarf', 'dwarfs', 'dwarfy', 'dwarfish',
            'midget', 'midgets', 'midgety', 'midgetish',
            'fat', 'fats', 'fatty', 'fatish',
            'skinny', 'skinnies', 'skinniy', 'skinnish',
            'ugly', 'uglies', 'ugliy', 'uglish',
            'stupid', 'stupids', 'stupidy', 'stupidish',
            'dumb', 'dumbs', 'dumby', 'dumbish',
            'idiot', 'idiots', 'idioty', 'idiotish',
            'moron', 'morons', 'morony', 'moronish',
            'retard', 'retards', 'retardy', 'retardish',
            'autistic', 'autistics', 'autisticy', 'autisticish',
            'downs', 'downsy', 'downsish',
            'mongoloid', 'mongoloids', 'mongoloidy', 'mongoloidish',
            'cripple', 'cripples', 'crippling', 'crippled', 'crippler', 'cripplers',
            'handicap', 'handicaps', 'handicapping', 'handicapped', 'handicapper', 'handicappers',
            'disabled', 'disableds', 'disabledy', 'disabledish',
            'blind', 'blinds', 'blindy', 'blindish',
            'deaf', 'deafs', 'deafy', 'deafish',
            'mute', 'mutes', 'muty', 'muteish',
            'dwarf', 'dwarfs', 'dwarfy', 'dwarfish',
            'midget', 'midgets', 'midgety', 'midgetish',
            'fat', 'fats', 'fatty', 'fatish',
            'skinny', 'skinnies', 'skinniy', 'skinnish',
            'ugly', 'uglies', 'ugliy', 'uglish',
            # Obscured profanity patterns
            'f*ck', 'f**k', 'f***', 'f*ck*ng', 'f**k*ng', 'f***ng',
            'sh*t', 'sh**', 'sh***', 'sh*tt*ng', 'sh**t*ng', 'sh***ng',
            'b*tch', 'b**ch', 'b***h', 'b*tch*ng', 'b**ch*ng', 'b***h*ng',
            'a*s', 'a**', 'a***', 'a*sh*le', 'a**h*le', 'a***h*le',
            'd*mn', 'd**n', 'd***', 'd*mn*t', 'd**n*t', 'd***n*t',
            'h*ll', 'h**l', 'h***', 'h*ll*sh', 'h**l*sh', 'h***l*sh',
            'cr*p', 'cr**', 'cr***', 'cr*pp*', 'cr**p*', 'cr***p*',
            'p*ss', 'p**s', 'p***', 'p*ss*ng', 'p**s*ng', 'p***s*ng',
            'd*ck', 'd**k', 'd***', 'd*ck*ng', 'd**k*ng', 'd***k*ng',
            'c*ck', 'c**k', 'c***', 'c*ck*ng', 'c**k*ng', 'c***k*ng',
            'p*ssy', 'p**sy', 'p***y', 'p*ssy*ng', 'p**sy*ng', 'p***sy*ng',
            't*ts', 't**s', 't***', 't*ts*ng', 't**s*ng', 't***s*ng',
            'b**bs', 'b***s', 'b****', 'b**bs*ng', 'b***s*ng', 'b****s*ng',
            'wh*re', 'wh**e', 'wh***', 'wh*re*ng', 'wh**e*ng', 'wh***e*ng',
            'sl*t', 'sl**', 'sl***', 'sl*t*ng', 'sl**t*ng', 'sl***t*ng',
            'h*e', 'h**', 'h***', 'h*e*ng', 'h**e*ng', 'h***e*ng',
            'n*gg*r', 'n**g*r', 'n***g*r', 'n*gg*ng', 'n**g*ng', 'n***g*ng',
            'ch*nk', 'ch**k', 'ch***k', 'ch*nk*ng', 'ch**k*ng', 'ch***k*ng',
            'k*ke', 'k**e', 'k***e', 'k*ke*ng', 'k**e*ng', 'k***e*ng',
            'sp*c', 'sp**', 'sp***', 'sp*c*ng', 'sp**c*ng', 'sp***c*ng',
            'w*tb*ck', 'w**tb*ck', 'w***tb*ck', 'w*tb*ck*ng', 'w**tb*ck*ng', 'w***tb*ck*ng',
            't*w*lh*ad', 't**w*lh*ad', 't***w*lh*ad', 't*w*lh*ad*ng', 't**w*lh*ad*ng', 't***w*lh*ad*ng',
            's*ndn*gg*r', 's**ndn*gg*r', 's***ndn*gg*r', 's*ndn*gg*r*ng', 's**ndn*gg*r*ng', 's***ndn*gg*r*ng',
            'r*gh*ad', 'r**gh*ad', 'r***gh*ad', 'r*gh*ad*ng', 'r**gh*ad*ng', 'r***gh*ad*ng',
            't*rr*r*st', 't**rr*r*st', 't***rr*r*st', 't*rr*r*st*ng', 't**rr*r*st*ng', 't***rr*r*st*ng',
            'b*mber', 'b**mber', 'b***mber', 'b*mber*ng', 'b**mber*ng', 'b***mber*ng',
            's*ic*de', 's**ic*de', 's***ic*de', 's*ic*de*ng', 's**ic*de*ng', 's***ic*de*ng',
            'b*mb', 'b**mb', 'b***mb', 'b*mb*ng', 'b**mb*ng', 'b***mb*ng',
            'k*ll', 'k**ll', 'k***ll', 'k*ll*ng', 'k**ll*ng', 'k***ll*ng',
            'm*rd*r', 'm**rd*r', 'm***rd*r', 'm*rd*r*ng', 'm**rd*r*ng', 'm***rd*r*ng',
            'd*ath', 'd**ath', 'd***ath', 'd*ath*ng', 'd**ath*ng', 'd***ath*ng',
            'd*e', 'd**e', 'd***e', 'd*e*ng', 'd**e*ng', 'd***e*ng',
            'd*ad', 'd**ad', 'd***ad', 'd*ad*ng', 'd**ad*ng', 'd***ad*ng',
            'h*te', 'h**te', 'h***te', 'h*te*ng', 'h**te*ng', 'h***te*ng',
            'r*c*st', 'r**c*st', 'r***c*st', 'r*c*st*ng', 'r**c*st*ng', 'r***c*st*ng',
            'n*z*', 'n**z*', 'n***z*', 'n*z**ng', 'n**z**ng', 'n***z**ng',
            'h*tl*r', 'h**tl*r', 'h***tl*r', 'h*tl*r*ng', 'h**tl*r*ng', 'h***tl*r*ng',
            'k*k', 'k**k', 'k***k', 'k*k*ng', 'k**k*ng', 'k***k*ng',
            'wh*te', 'wh**te', 'wh***te', 'wh*te*ng', 'wh**te*ng', 'wh***te*ng',
            'bl*ck', 'bl**ck', 'bl***ck', 'bl*ck*ng', 'bl**ck*ng', 'bl***ck*ng',
            'y*ll*w', 'y**ll*w', 'y***ll*w', 'y*ll*w*ng', 'y**ll*w*ng', 'y***ll*w*ng',
            'r*d', 'r**d', 'r***d', 'r*d*ng', 'r**d*ng', 'r***d*ng',
            'br*wn', 'br**wn', 'br***wn', 'br*wn*ng', 'br**wn*ng', 'br***wn*ng',
            'g*y', 'g**y', 'g***y', 'g*y*ng', 'g**y*ng', 'g***y*ng',
            'l*sb*an', 'l**sb*an', 'l***sb*an', 'l*sb*an*ng', 'l**sb*an*ng', 'l***sb*an*ng',
            'f*g', 'f**g', 'f***g', 'f*g*ng', 'f**g*ng', 'f***g*ng',
            'f*gg*t', 'f**gg*t', 'f***gg*t', 'f*gg*t*ng', 'f**gg*t*ng', 'f***gg*t*ng',
            'd*ke', 'd**ke', 'd***ke', 'd*ke*ng', 'd**ke*ng', 'd***ke*ng',
            'tr*nny', 'tr**nny', 'tr***nny', 'tr*nny*ng', 'tr**nny*ng', 'tr***nny*ng',
            'sh*m*le', 'sh**m*le', 'sh***m*le', 'sh*m*le*ng', 'sh**m*le*ng', 'sh***m*le*ng',
            'l*dyb*y', 'l**dyb*y', 'l***dyb*y', 'l*dyb*y*ng', 'l**dyb*y*ng', 'l***dyb*y*ng',
            'r*t*rd', 'r**t*rd', 'r***t*rd', 'r*t*rd*ng', 'r**t*rd*ng', 'r***t*rd*ng',
            'r*t*rd*t*on', 'r**t*rd*t*on', 'r***t*rd*t*on', 'r*t*rd*t*on*ng', 'r**t*rd*t*on*ng', 'r***t*rd*t*on*ng',
            '*d*ot', '**d*ot', '***d*ot', '*d*ot*ng', '**d*ot*ng', '***d*ot*ng',
            'm*ron', 'm**ron', 'm***ron', 'm*ron*ng', 'm**ron*ng', 'm***ron*ng',
            'st*p*d', 'st**p*d', 'st***p*d', 'st*p*d*ng', 'st**p*d*ng', 'st***p*d*ng',
            'd*mb', 'd**mb', 'd***mb', 'd*mb*ng', 'd**mb*ng', 'd***mb*ng',
            'r*t*rd', 'r**t*rd', 'r***t*rd', 'r*t*rd*ng', 'r**t*rd*ng', 'r***t*rd*ng',
            'a*t*st*c', 'a**t*st*c', 'a***t*st*c', 'a*t*st*c*ng', 'a**t*st*c*ng', 'a***t*st*c*ng',
            'd*wns', 'd**wns', 'd***wns', 'd*wns*ng', 'd**wns*ng', 'd***wns*ng',
            'm*ng*l*id', 'm**ng*l*id', 'm***ng*l*id', 'm*ng*l*id*ng', 'm**ng*l*id*ng', 'm***ng*l*id*ng',
            'cr*ppl*', 'cr**ppl*', 'cr***ppl*', 'cr*ppl*ng', 'cr**ppl*ng', 'cr***ppl*ng',
            'h*nd*c*p', 'h**nd*c*p', 'h***nd*c*p', 'h*nd*c*p*ng', 'h**nd*c*p*ng', 'h***nd*c*p*ng',
            'd*s*bl*d', 'd**s*bl*d', 'd***s*bl*d', 'd*s*bl*d*ng', 'd**s*bl*d*ng', 'd***s*bl*d*ng',
            'bl*nd', 'bl**nd', 'bl***nd', 'bl*nd*ng', 'bl**nd*ng', 'bl***nd*ng',
            'd*f', 'd**f', 'd***f', 'd*f*ng', 'd**f*ng', 'd***f*ng',
            'm*te', 'm**te', 'm***te', 'm*te*ng', 'm**te*ng', 'm***te*ng',
            'dw*rf', 'dw**rf', 'dw***rf', 'dw*rf*ng', 'dw**rf*ng', 'dw***rf*ng',
            'm*dg*t', 'm**dg*t', 'm***dg*t', 'm*dg*t*ng', 'm**dg*t*ng', 'm***dg*t*ng',
            'f*t', 'f**t', 'f***t', 'f*t*ng', 'f**t*ng', 'f***t*ng',
            'sk*nny', 'sk**nny', 'sk***nny', 'sk*nny*ng', 'sk**nny*ng', 'sk***nny*ng',
            '*gly', '**gly', '***gly', '*gly*ng', '**gly*ng', '***gly*ng',
            'st*p*d', 'st**p*d', 'st***p*d', 'st*p*d*ng', 'st**p*d*ng', 'st***p*d*ng',
            'd*mb', 'd**mb', 'd***mb', 'd*mb*ng', 'd**mb*ng', 'd***mb*ng',
            '*d*ot', '**d*ot', '***d*ot', '*d*ot*ng', '**d*ot*ng', '***d*ot*ng',
            'm*ron', 'm**ron', 'm***ron', 'm*ron*ng', 'm**ron*ng', 'm***ron*ng',
            'r*t*rd', 'r**t*rd', 'r***t*rd', 'r*t*rd*ng', 'r**t*rd*ng', 'r***t*rd*ng',
            'a*t*st*c', 'a**t*st*c', 'a***t*st*c', 'a*t*st*c*ng', 'a**t*st*c*ng', 'a***t*st*c*ng',
            'd*wns', 'd**wns', 'd***wns', 'd*wns*ng', 'd**wns*ng', 'd***wns*ng',
            'm*ng*l*id', 'm**ng*l*id', 'm***ng*l*id', 'm*ng*l*id*ng', 'm**ng*l*id*ng', 'm***ng*l*id*ng',
            'cr*ppl*', 'cr**ppl*', 'cr***ppl*', 'cr*ppl*ng', 'cr**ppl*ng', 'cr***ppl*ng',
            'h*nd*c*p', 'h**nd*c*p', 'h***nd*c*p', 'h*nd*c*p*ng', 'h**nd*c*p*ng', 'h***nd*c*p*ng',
            'd*s*bl*d', 'd**s*bl*d', 'd***s*bl*d', 'd*s*bl*d*ng', 'd**s*bl*d*ng', 'd***s*bl*d*ng',
            'bl*nd', 'bl**nd', 'bl***nd', 'bl*nd*ng', 'bl**nd*ng', 'bl***nd*ng',
            'd*f', 'd**f', 'd***f', 'd*f*ng', 'd**f*ng', 'd***f*ng',
            'm*te', 'm**te', 'm***te', 'm*te*ng', 'm**te*ng', 'm***te*ng',
            'dw*rf', 'dw**rf', 'dw***rf', 'dw*rf*ng', 'dw**rf*ng', 'dw***rf*ng',
            'm*dg*t', 'm**dg*t', 'm***dg*t', 'm*dg*t*ng', 'm**dg*t*ng', 'm***dg*t*ng',
            'f*t', 'f**t', 'f***t', 'f*t*ng', 'f**t*ng', 'f***t*ng',
            'sk*nny', 'sk**nny', 'sk***nny', 'sk*nny*ng', 'sk**nny*ng', 'sk***nny*ng',
            '*gly', '**gly', '***gly', '*gly*ng', '**gly*ng', '***gly*ng'
        ]
        
        # Check for exact matches
        for word in inappropriate_words:
            if word in text_lower:
                return True
        
        # Check for obfuscated patterns (common substitutions)
        obfuscated_patterns = [
            # Common character substitutions
            (r'[0o]', 'o'),  # 0 or o
            (r'[1i!l]', 'i'),  # 1, i, !, or l
            (r'[3e]', 'e'),  # 3 or e
            (r'[4a@]', 'a'),  # 4, a, or @
            (r'[5s$]', 's'),  # 5, s, or $
            (r'[6g]', 'g'),  # 6 or g
            (r'[7t]', 't'),  # 7 or t
            (r'[8b]', 'b'),  # 8 or b
            (r'[9g]', 'g'),  # 9 or g
            (r'[|!1]', 'i'),  # |, !, or 1
            (r'[*]', ''),  # Remove asterisks
            (r'[-_]', ''),  # Remove hyphens and underscores
        ]
        
        # Normalize text by applying obfuscation patterns
        normalized_text = text_lower
        for pattern, replacement in obfuscated_patterns:
            normalized_text = re.sub(pattern, replacement, normalized_text)
        
        # Check normalized text against inappropriate words
        for word in inappropriate_words:
            if word in normalized_text:
                return True
        
        # Check for repeated characters (e.g., "fuuuuck")
        repeated_pattern = r'(.)\1{2,}'
        if re.search(repeated_pattern, text_lower):
            # Check if the repeated character forms an inappropriate word
            for word in inappropriate_words:
                if len(word) > 2:  # Only check longer words
                    # Create pattern with repeated characters
                    repeated_word = ''.join([char + '{1,}' for char in word])
                    if re.search(repeated_word, text_lower):
                        return True
        
        return False
    
    @classmethod
    def validate_phone_number(cls, phone: str) -> str:
        """
        Validate and sanitize phone number
        
        Args:
            phone: Phone number to validate
            
        Returns:
            Sanitized phone number
            
        Raises:
            HTTPException: If phone number is invalid
        """
        if not phone:
            return ""
        
        # Remove all non-digit characters
        digits_only = re.sub(r'\D', '', phone)
        
        # Validate length (7-15 digits is standard)
        if len(digits_only) < 7 or len(digits_only) > 15:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid phone number format"
            )
        
        return digits_only
    
    @classmethod
    def validate_file_upload(cls, filename: str, content_type: str, size: int) -> bool:
        """
        Validate file upload
        
        Args:
            filename: Name of the file
            content_type: MIME type of the file
            size: File size in bytes
            
        Returns:
            True if valid
            
        Raises:
            HTTPException: If file is invalid
        """
        # Check file size
        max_size = settings.max_file_size_mb * 1024 * 1024  # Convert MB to bytes
        if size > max_size:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File size exceeds maximum allowed size of {settings.max_file_size_mb}MB"
            )
        
        # Check file extension
        allowed_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
        file_ext = filename.lower().split('.')[-1] if '.' in filename else ''
        
        if f'.{file_ext}' not in allowed_extensions:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file type. Only image files are allowed"
            )
        
        # Check MIME type
        allowed_mime_types = [
            'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 
            'image/bmp', 'image/webp'
        ]
        
        if content_type not in allowed_mime_types:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file type. Only image files are allowed"
            )
        
        return True
    
    @classmethod
    def validate_json_input(cls, data: Dict[str, Any], max_depth: int = 10) -> Dict[str, Any]:
        """
        Validate JSON input for security
        
        Args:
            data: JSON data to validate
            max_depth: Maximum nesting depth
            
        Returns:
            Validated data
            
        Raises:
            HTTPException: If data is invalid
        """
        def check_depth(obj, current_depth=0):
            if current_depth > max_depth:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="JSON structure too deep"
                )
            
            if isinstance(obj, dict):
                for key, value in obj.items():
                    # Sanitize keys
                    if not isinstance(key, str):
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="Invalid JSON key type"
                        )
                    
                    # Check key length
                    if len(key) > 100:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="JSON key too long"
                        )
                    
                    check_depth(value, current_depth + 1)
            elif isinstance(obj, list):
                if len(obj) > 1000:  # Limit array size
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Array too large"
                    )
                
                for item in obj:
                    check_depth(item, current_depth + 1)
            elif isinstance(obj, str):
                # Sanitize string values
                if len(obj) > 10000:  # Limit string length
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="String too long"
                    )
        
        check_depth(data)
        return data
