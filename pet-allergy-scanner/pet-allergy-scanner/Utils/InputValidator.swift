//
//  InputValidator.swift
//  pet-allergy-scanner
//
//  Created by Code Assistant, 2025.
//

import Foundation

/// Input validation utility for secure user input handling
struct InputValidator {
    
    /// Validate email format
    /// - Parameter email: Email string to validate
    /// - Returns: True if email is valid
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Validate username format with profanity filtering
    /// - Parameter username: Username string to validate
    /// - Returns: True if username is valid
    static func isValidUsername(_ username: String) -> Bool {
        // Check length (3-30 characters)
        guard username.count >= 3 && username.count <= 30 else {
            return false
        }
        
        // Check for valid characters (alphanumeric, underscore, hyphen)
        let usernameRegex = "^[a-zA-Z0-9_-]+$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        guard usernamePredicate.evaluate(with: username) else {
            return false
        }
        
        // Check if starts with letter or number
        guard username.first?.isLetter == true || username.first?.isNumber == true else {
            return false
        }
        
        // Check for profanity and inappropriate content
        if containsInappropriateContent(username) {
            return false
        }
        
        // Check for reserved usernames
        let reservedUsernames = [
            "admin", "administrator", "root", "user", "guest", "test", "api",
            "www", "mail", "ftp", "support", "help", "info", "contact",
            "about", "privacy", "terms", "legal", "security", "auth",
            "login", "logout", "register", "signup", "signin", "signout",
            "password", "reset", "forgot", "verify", "confirm", "activate",
            "deactivate", "delete", "remove", "update", "edit", "create",
            "new", "old", "current", "previous", "next", "first", "last",
            "home", "dashboard", "profile", "settings", "account", "billing",
            "payment", "subscription", "premium", "free", "basic", "pro",
            "enterprise", "business", "personal", "private", "public",
            "system", "service", "app", "application", "mobile", "web",
            "desktop", "client", "server", "database", "api", "rest",
            "graphql", "oauth", "jwt", "token", "session", "cookie",
            "cache", "redis", "postgres", "mysql", "sqlite", "mongodb"
        ]
        
        return !reservedUsernames.contains(username.lowercased())
    }
    
    /// Check if text contains inappropriate content
    /// - Parameter text: Text to check
    /// - Returns: True if inappropriate content is found
    private static func containsInappropriateContent(_ text: String) -> Bool {
        let textLower = text.lowercased()
        
        // Comprehensive profanity and inappropriate content list
        let inappropriateWords = [
            // Common profanity
            "fuck", "fucking", "fucked", "fucker", "fucks", "fuckin",
            "shit", "shitting", "shitted", "shitter", "shits", "shitty",
            "bitch", "bitches", "bitching", "bitched", "bitchy",
            "ass", "asses", "asshole", "assholes", "asshat", "asshats",
            "damn", "damned", "damning", "damnit", "dammit",
            "hell", "hells", "hellish", "hellishness",
            "crap", "crappy", "crappier", "crappiest",
            "piss", "pissing", "pissed", "pisser", "pisses", "pissy",
            "dick", "dicks", "dickhead", "dickheads", "dickish",
            "cock", "cocks", "cocky", "cockhead", "cockheads",
            "pussy", "pussies", "pussycats", "pussyfoot",
            "tits", "titties", "tit", "titty", "titsy",
            "boob", "boobs", "boobies", "booby", "boobish",
            "whore", "whores", "whoring", "whored", "whorish",
            "slut", "sluts", "slutting", "slutty", "sluttish",
            "hoe", "hoes", "hoing", "hoed", "hoish",
            "nigger", "niggers", "nigga", "niggas", "niggah", "niggahs",
            "chink", "chinks", "chinky", "chinkish",
            "kike", "kikes", "kikey", "kikeish",
            "spic", "spics", "spicky", "spickish",
            "wetback", "wetbacks", "wetbacky", "wetbackish",
            "towelhead", "towelheads", "towelheady", "towelheadish",
            "sandnigger", "sandniggers", "sandnigga", "sandniggas",
            "raghead", "ragheads", "ragheady", "ragheadish",
            "terrorist", "terrorists", "terroristy", "terroristish",
            "bomber", "bombers", "bombery", "bomberish",
            "suicide", "suicides", "suicidy", "suicidish",
            "bomb", "bombs", "bomby", "bombish",
            "kill", "kills", "killing", "killed", "killer", "killers",
            "murder", "murders", "murdering", "murdered", "murderer", "murderers",
            "death", "deaths", "deathy", "deathish",
            "die", "dies", "dying", "died", "dier", "diers",
            "dead", "deads", "deady", "deadish",
            "hate", "hates", "hating", "hated", "hater", "haters",
            "racist", "racists", "racisty", "racistish",
            "nazi", "nazis", "naziy", "nazish",
            "hitler", "hitlers", "hitlery", "hitlerish",
            "kkk", "klan", "klans", "klany", "klanish",
            "white", "whites", "whitey", "whiteish",
            "black", "blacks", "blacky", "blackish",
            "yellow", "yellows", "yellowy", "yellowish",
            "red", "reds", "reddy", "reddish",
            "brown", "browns", "browny", "brownish",
            "gay", "gays", "gayy", "gayish",
            "lesbian", "lesbians", "lesbiany", "lesbianish",
            "fag", "fags", "faggy", "faggish",
            "faggot", "faggots", "faggoty", "faggotish",
            "dyke", "dykes", "dykey", "dykish",
            "tranny", "trannies", "trannyish", "trannish",
            "shemale", "shemales", "shemaley", "shemaleish",
            "ladyboy", "ladyboys", "ladyboyy", "ladyboyish",
            "retard", "retards", "retarding", "retarded", "retarder", "retarders",
            "retardation", "retardations", "retardationy", "retardationish",
            "idiot", "idiots", "idioty", "idiotish",
            "moron", "morons", "morony", "moronish",
            "stupid", "stupids", "stupidy", "stupidish",
            "dumb", "dumbs", "dumby", "dumbish",
            "autistic", "autistics", "autisticy", "autisticish",
            "downs", "downsy", "downsish",
            "mongoloid", "mongoloids", "mongoloidy", "mongoloidish",
            "cripple", "cripples", "crippling", "crippled", "crippler", "cripplers",
            "handicap", "handicaps", "handicapping", "handicapped", "handicapper", "handicappers",
            "disabled", "disableds", "disabledy", "disabledish",
            "blind", "blinds", "blindy", "blindish",
            "deaf", "deafs", "deafy", "deafish",
            "mute", "mutes", "muty", "muteish",
            "dwarf", "dwarfs", "dwarfy", "dwarfish",
            "midget", "midgets", "midgety", "midgetish",
            "fat", "fats", "fatty", "fatish",
            "skinny", "skinnies", "skinniy", "skinnish",
            "ugly", "uglies", "ugliy", "uglish",
            // Obscured profanity patterns
            "f*ck", "f**k", "f***", "f*ck*ng", "f**k*ng", "f***ng",
            "sh*t", "sh**", "sh***", "sh*tt*ng", "sh**t*ng", "sh***ng",
            "b*tch", "b**ch", "b***h", "b*tch*ng", "b**ch*ng", "b***h*ng",
            "a*s", "a**", "a***", "a*sh*le", "a**h*le", "a***h*le",
            "d*mn", "d**n", "d***", "d*mn*t", "d**n*t", "d***n*t",
            "h*ll", "h**l", "h***", "h*ll*sh", "h**l*sh", "h***l*sh",
            "cr*p", "cr**", "cr***", "cr*pp*", "cr**p*", "cr***p*",
            "p*ss", "p**s", "p***", "p*ss*ng", "p**s*ng", "p***s*ng",
            "d*ck", "d**k", "d***", "d*ck*ng", "d**k*ng", "d***k*ng",
            "c*ck", "c**k", "c***", "c*ck*ng", "c**k*ng", "c***k*ng",
            "p*ssy", "p**sy", "p***y", "p*ssy*ng", "p**sy*ng", "p***sy*ng",
            "t*ts", "t**s", "t***", "t*ts*ng", "t**s*ng", "t***s*ng",
            "b**bs", "b***s", "b****", "b**bs*ng", "b***s*ng", "b****s*ng",
            "wh*re", "wh**e", "wh***", "wh*re*ng", "wh**e*ng", "wh***e*ng",
            "sl*t", "sl**", "sl***", "sl*t*ng", "sl**t*ng", "sl***t*ng",
            "h*e", "h**", "h***", "h*e*ng", "h**e*ng", "h***e*ng",
            "n*gg*r", "n**g*r", "n***g*r", "n*gg*ng", "n**g*ng", "n***g*ng",
            "ch*nk", "ch**k", "ch***k", "ch*nk*ng", "ch**k*ng", "ch***k*ng",
            "k*ke", "k**e", "k***e", "k*ke*ng", "k**e*ng", "k***e*ng",
            "sp*c", "sp**", "sp***", "sp*c*ng", "sp**c*ng", "sp***c*ng",
            "w*tb*ck", "w**tb*ck", "w***tb*ck", "w*tb*ck*ng", "w**tb*ck*ng", "w***tb*ck*ng",
            "t*w*lh*ad", "t**w*lh*ad", "t***w*lh*ad", "t*w*lh*ad*ng", "t**w*lh*ad*ng", "t***w*lh*ad*ng",
            "s*ndn*gg*r", "s**ndn*gg*r", "s***ndn*gg*r", "s*ndn*gg*r*ng", "s**ndn*gg*r*ng", "s***ndn*gg*r*ng",
            "r*gh*ad", "r**gh*ad", "r***gh*ad", "r*gh*ad*ng", "r**gh*ad*ng", "r***gh*ad*ng",
            "t*rr*r*st", "t**rr*r*st", "t***rr*r*st", "t*rr*r*st*ng", "t**rr*r*st*ng", "t***rr*r*st*ng",
            "b*mber", "b**mber", "b***mber", "b*mber*ng", "b**mber*ng", "b***mber*ng",
            "s*ic*de", "s**ic*de", "s***ic*de", "s*ic*de*ng", "s**ic*de*ng", "s***ic*de*ng",
            "b*mb", "b**mb", "b***mb", "b*mb*ng", "b**mb*ng", "b***mb*ng",
            "k*ll", "k**ll", "k***ll", "k*ll*ng", "k**ll*ng", "k***ll*ng",
            "m*rd*r", "m**rd*r", "m***rd*r", "m*rd*r*ng", "m**rd*r*ng", "m***rd*r*ng",
            "d*ath", "d**ath", "d***ath", "d*ath*ng", "d**ath*ng", "d***ath*ng",
            "d*e", "d**e", "d***e", "d*e*ng", "d**e*ng", "d***e*ng",
            "d*ad", "d**ad", "d***ad", "d*ad*ng", "d**ad*ng", "d***ad*ng",
            "h*te", "h**te", "h***te", "h*te*ng", "h**te*ng", "h***te*ng",
            "r*c*st", "r**c*st", "r***c*st", "r*c*st*ng", "r**c*st*ng", "r***c*st*ng",
            "n*z*", "n**z*", "n***z*", "n*z**ng", "n**z**ng", "n***z**ng",
            "h*tl*r", "h**tl*r", "h***tl*r", "h*tl*r*ng", "h**tl*r*ng", "h***tl*r*ng",
            "k*k", "k**k", "k***k", "k*k*ng", "k**k*ng", "k***k*ng",
            "wh*te", "wh**te", "wh***te", "wh*te*ng", "wh**te*ng", "wh***te*ng",
            "bl*ck", "bl**ck", "bl***ck", "bl*ck*ng", "bl**ck*ng", "bl***ck*ng",
            "y*ll*w", "y**ll*w", "y***ll*w", "y*ll*w*ng", "y**ll*w*ng", "y***ll*w*ng",
            "r*d", "r**d", "r***d", "r*d*ng", "r**d*ng", "r***d*ng",
            "br*wn", "br**wn", "br***wn", "br*wn*ng", "br**wn*ng", "br***wn*ng",
            "g*y", "g**y", "g***y", "g*y*ng", "g**y*ng", "g***y*ng",
            "l*sb*an", "l**sb*an", "l***sb*an", "l*sb*an*ng", "l**sb*an*ng", "l***sb*an*ng",
            "f*g", "f**g", "f***g", "f*g*ng", "f**g*ng", "f***g*ng",
            "f*gg*t", "f**gg*t", "f***gg*t", "f*gg*t*ng", "f**gg*t*ng", "f***gg*t*ng",
            "d*ke", "d**ke", "d***ke", "d*ke*ng", "d**ke*ng", "d***ke*ng",
            "tr*nny", "tr**nny", "tr***nny", "tr*nny*ng", "tr**nny*ng", "tr***nny*ng",
            "sh*m*le", "sh**m*le", "sh***m*le", "sh*m*le*ng", "sh**m*le*ng", "sh***m*le*ng",
            "l*dyb*y", "l**dyb*y", "l***dyb*y", "l*dyb*y*ng", "l**dyb*y*ng", "l***dyb*y*ng",
            "r*t*rd", "r**t*rd", "r***t*rd", "r*t*rd*ng", "r**t*rd*ng", "r***t*rd*ng",
            "r*t*rd*t*on", "r**t*rd*t*on", "r***t*rd*t*on", "r*t*rd*t*on*ng", "r**t*rd*t*on*ng", "r***t*rd*t*on*ng",
            "*d*ot", "**d*ot", "***d*ot", "*d*ot*ng", "**d*ot*ng", "***d*ot*ng",
            "m*ron", "m**ron", "m***ron", "m*ron*ng", "m**ron*ng", "m***ron*ng",
            "st*p*d", "st**p*d", "st***p*d", "st*p*d*ng", "st**p*d*ng", "st***p*d*ng",
            "d*mb", "d**mb", "d***mb", "d*mb*ng", "d**mb*ng", "d***mb*ng",
            "r*t*rd", "r**t*rd", "r***t*rd", "r*t*rd*ng", "r**t*rd*ng", "r***t*rd*ng",
            "a*t*st*c", "a**t*st*c", "a***t*st*c", "a*t*st*c*ng", "a**t*st*c*ng", "a***t*st*c*ng",
            "d*wns", "d**wns", "d***wns", "d*wns*ng", "d**wns*ng", "d***wns*ng",
            "m*ng*l*id", "m**ng*l*id", "m***ng*l*id", "m*ng*l*id*ng", "m**ng*l*id*ng", "m***ng*l*id*ng",
            "cr*ppl*", "cr**ppl*", "cr***ppl*", "cr*ppl*ng", "cr**ppl*ng", "cr***ppl*ng",
            "h*nd*c*p", "h**nd*c*p", "h***nd*c*p", "h*nd*c*p*ng", "h**nd*c*p*ng", "h***nd*c*p*ng",
            "d*s*bl*d", "d**s*bl*d", "d***s*bl*d", "d*s*bl*d*ng", "d**s*bl*d*ng", "d***s*bl*d*ng",
            "bl*nd", "bl**nd", "bl***nd", "bl*nd*ng", "bl**nd*ng", "bl***nd*ng",
            "d*f", "d**f", "d***f", "d*f*ng", "d**f*ng", "d***f*ng",
            "m*te", "m**te", "m***te", "m*te*ng", "m**te*ng", "m***te*ng",
            "dw*rf", "dw**rf", "dw***rf", "dw*rf*ng", "dw**rf*ng", "dw***rf*ng",
            "m*dg*t", "m**dg*t", "m***dg*t", "m*dg*t*ng", "m**dg*t*ng", "m***dg*t*ng",
            "f*t", "f**t", "f***t", "f*t*ng", "f**t*ng", "f***t*ng",
            "sk*nny", "sk**nny", "sk***nny", "sk*nny*ng", "sk**nny*ng", "sk***nny*ng",
            "*gly", "**gly", "***gly", "*gly*ng", "**gly*ng", "***gly*ng"
        ]
        
        // Check for exact matches
        for word in inappropriateWords {
            if textLower.contains(word) {
                return true
            }
        }
        
        // Check for obfuscated patterns (common substitutions)
        let obfuscatedPatterns = [
            ("[0o]", "o"),  // 0 or o
            ("[1i!l]", "i"),  // 1, i, !, or l
            ("[3e]", "e"),  // 3 or e
            ("[4a@]", "a"),  // 4, a, or @
            ("[5s$]", "s"),  // 5, s, or $
            ("[6g]", "g"),  // 6 or g
            ("[7t]", "t"),  // 7 or t
            ("[8b]", "b"),  // 8 or b
            ("[9g]", "g"),  // 9 or g
            ("[|!1]", "i"),  // |, !, or 1
            ("[*]", ""),  // Remove asterisks
            ("[-_]", "")   // Remove hyphens and underscores
        ]
        
        // Normalize text by applying obfuscation patterns
        var normalizedText = textLower
        for (pattern, replacement) in obfuscatedPatterns {
            normalizedText = normalizedText.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        
        // Check normalized text against inappropriate words
        for word in inappropriateWords {
            if normalizedText.contains(word) {
                return true
            }
        }
        
        // Check for repeated characters (e.g., "fuuuuck")
        let repeatedPattern = "(.)\\1{2,}"
        if textLower.range(of: repeatedPattern, options: .regularExpression) != nil {
            // Check if the repeated character forms an inappropriate word
            for word in inappropriateWords {
                if word.count > 2 {  // Only check longer words
                    // Create pattern with repeated characters
                    let repeatedWord = word.map { "\($0){1,}" }.joined()
                    if textLower.range(of: repeatedWord, options: .regularExpression) != nil {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Validate password strength
    /// - Parameter password: Password string to validate
    /// - Returns: Password validation result
    static func validatePassword(_ password: String) -> PasswordValidationResult {
        var issues: [String] = []
        
        if password.count < 8 {
            issues.append("Password must be at least 8 characters long")
        }
        
        if password.count > 64 {
            issues.append("Password must be less than 64 characters")
        }
        
        if !password.contains(where: { $0.isUppercase }) {
            issues.append("Password must contain at least one uppercase letter")
        }
        
        if !password.contains(where: { $0.isLowercase }) {
            issues.append("Password must contain at least one lowercase letter")
        }
        
        if !password.contains(where: { $0.isNumber }) {
            issues.append("Password must contain at least one number")
        }
        
        let specialCharacters = "!@#$%^&*(),.?\":{}|<>"
        if !password.contains(where: { specialCharacters.contains($0) }) {
            issues.append("Password must contain at least one special character")
        }
        
        return PasswordValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// Sanitize user input to prevent injection attacks
    /// - Parameters:
    ///   - input: Input string to sanitize
    ///   - maxLength: Maximum allowed length
    /// - Returns: Sanitized string
    static func sanitizeInput(_ input: String, maxLength: Int = 255) -> String {
        // Remove HTML tags and potentially dangerous characters
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
            .union(.symbols)
        
        let sanitized = input.components(separatedBy: allowedCharacterSet.inverted).joined()
        
        // Truncate to max length
        return String(sanitized.prefix(maxLength))
    }
    
    /// Validate phone number format (E.164)
    /// - Parameter phoneNumber: Phone number string
    /// - Returns: True if phone number is valid
    static func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        let phoneRegex = "^\\+[1-9]\\d{1,14}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phoneNumber)
    }
    
    /// Validate pet name
    /// - Parameter name: Pet name string
    /// - Returns: True if pet name is valid
    static func isValidPetName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName.count <= 50
    }
    
    /// Validate ingredient text
    /// - Parameter text: Ingredient text string
    /// - Returns: True if ingredient text is valid
    static func isValidIngredientText(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty && trimmedText.count <= 10000
    }
    
    /// Validate file size
    /// - Parameters:
    ///   - size: File size in bytes
    ///   - maxSizeMB: Maximum allowed size in MB
    /// - Returns: True if file size is valid
    static func isValidFileSize(_ size: Int64, maxSizeMB: Int = 10) -> Bool {
        let maxSizeBytes = Int64(maxSizeMB) * 1024 * 1024
        return size <= maxSizeBytes
    }
    
    /// Validate MFA token format
    /// - Parameter token: MFA token string
    /// - Returns: True if token format is valid
    static func isValidMFAToken(_ token: String) -> Bool {
        return token.count == 6 && token.allSatisfy { $0.isNumber }
    }
    
    /// Validate backup code format
    /// - Parameter code: Backup code string
    /// - Returns: True if backup code format is valid
    static func isValidBackupCode(_ code: String) -> Bool {
        return code.count == 8 && code.allSatisfy { $0.isLetter || $0.isNumber }
    }
}

/// Password validation result
struct PasswordValidationResult {
    let isValid: Bool
    let issues: [String]
    
    var strength: PasswordStrength {
        if issues.isEmpty {
            return .strong
        } else if issues.count <= 2 {
            return .medium
        } else {
            return .weak
        }
    }
}

/// Password strength levels
enum PasswordStrength {
    case weak
    case medium
    case strong
    
    var color: String {
        switch self {
        case .weak:
            return "red"
        case .medium:
            return "orange"
        case .strong:
            return "green"
        }
    }
    
    var description: String {
        switch self {
        case .weak:
            return "Weak"
        case .medium:
            return "Medium"
        case .strong:
            return "Strong"
        }
    }
}
