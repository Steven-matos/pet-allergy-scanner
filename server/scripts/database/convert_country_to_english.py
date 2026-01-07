#!/usr/bin/env python3
"""
Country to English Conversion Script
Converts localized country names to English names in the food_items table

This script will:
1. Find all food items where country contains format 'code:localized_name' (e.g., 'es:España')
2. Convert them to 'code:English_name' (e.g., 'es:Spain')
3. Use ISO 3166-1 alpha-2 country code mappings
4. Provide statistics on what was converted

Usage:
    python scripts/database/convert_country_to_english.py [--dry-run] [--confirm]
"""

import asyncio
import sys
import os
from typing import List, Dict, Any, Optional
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Add the parent directory to the path so we can import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.config import settings
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ISO 3166-1 alpha-2 country code to English name mapping
COUNTRY_CODE_TO_ENGLISH = {
    "AD": "Andorra", "AE": "United Arab Emirates", "AF": "Afghanistan",
    "AG": "Antigua and Barbuda", "AI": "Anguilla", "AL": "Albania",
    "AM": "Armenia", "AO": "Angola", "AQ": "Antarctica",
    "AR": "Argentina", "AS": "American Samoa", "AT": "Austria",
    "AU": "Australia", "AW": "Aruba", "AX": "Åland Islands",
    "AZ": "Azerbaijan", "BA": "Bosnia and Herzegovina", "BB": "Barbados",
    "BD": "Bangladesh", "BE": "Belgium", "BF": "Burkina Faso",
    "BG": "Bulgaria", "BH": "Bahrain", "BI": "Burundi",
    "BJ": "Benin", "BL": "Saint Barthélemy", "BM": "Bermuda",
    "BN": "Brunei", "BO": "Bolivia", "BQ": "Caribbean Netherlands",
    "BR": "Brazil", "BS": "Bahamas", "BT": "Bhutan",
    "BV": "Bouvet Island", "BW": "Botswana", "BY": "Belarus",
    "BZ": "Belize", "CA": "Canada", "CC": "Cocos Islands",
    "CD": "Congo (DRC)", "CF": "Central African Republic", "CG": "Congo",
    "CH": "Switzerland", "CI": "Côte d'Ivoire", "CK": "Cook Islands",
    "CL": "Chile", "CM": "Cameroon", "CN": "China",
    "CO": "Colombia", "CR": "Costa Rica", "CU": "Cuba",
    "CV": "Cape Verde", "CW": "Curaçao", "CX": "Christmas Island",
    "CY": "Cyprus", "CZ": "Czech Republic", "DE": "Germany",
    "DJ": "Djibouti", "DK": "Denmark", "DM": "Dominica",
    "DO": "Dominican Republic", "DZ": "Algeria", "EC": "Ecuador",
    "EE": "Estonia", "EG": "Egypt", "EH": "Western Sahara",
    "ER": "Eritrea", "ES": "Spain", "ET": "Ethiopia",
    "FI": "Finland", "FJ": "Fiji", "FK": "Falkland Islands",
    "FM": "Micronesia", "FO": "Faroe Islands", "FR": "France",
    "GA": "Gabon", "GB": "United Kingdom", "GD": "Grenada",
    "GE": "Georgia", "GF": "French Guiana", "GG": "Guernsey",
    "GH": "Ghana", "GI": "Gibraltar", "GL": "Greenland",
    "GM": "Gambia", "GN": "Guinea", "GP": "Guadeloupe",
    "GQ": "Equatorial Guinea", "GR": "Greece", "GS": "South Georgia",
    "GT": "Guatemala", "GU": "Guam", "GW": "Guinea-Bissau",
    "GY": "Guyana", "HK": "Hong Kong", "HM": "Heard Island",
    "HN": "Honduras", "HR": "Croatia", "HT": "Haiti",
    "HU": "Hungary", "ID": "Indonesia", "IE": "Ireland",
    "IL": "Israel", "IM": "Isle of Man", "IN": "India",
    "IO": "British Indian Ocean Territory", "IQ": "Iraq", "IR": "Iran",
    "IS": "Iceland", "IT": "Italy", "JE": "Jersey",
    "JM": "Jamaica", "JO": "Jordan", "JP": "Japan",
    "KE": "Kenya", "KG": "Kyrgyzstan", "KH": "Cambodia",
    "KI": "Kiribati", "KM": "Comoros", "KN": "Saint Kitts and Nevis",
    "KP": "North Korea", "KR": "South Korea", "KW": "Kuwait",
    "KY": "Cayman Islands", "KZ": "Kazakhstan", "LA": "Laos",
    "LB": "Lebanon", "LC": "Saint Lucia", "LI": "Liechtenstein",
    "LK": "Sri Lanka", "LR": "Liberia", "LS": "Lesotho",
    "LT": "Lithuania", "LU": "Luxembourg", "LV": "Latvia",
    "LY": "Libya", "MA": "Morocco", "MC": "Monaco",
    "MD": "Moldova", "ME": "Montenegro", "MF": "Saint Martin",
    "MG": "Madagascar", "MH": "Marshall Islands", "MK": "North Macedonia",
    "ML": "Mali", "MM": "Myanmar", "MN": "Mongolia",
    "MO": "Macao", "MP": "Northern Mariana Islands", "MQ": "Martinique",
    "MR": "Mauritania", "MS": "Montserrat", "MT": "Malta",
    "MU": "Mauritius", "MV": "Maldives", "MW": "Malawi",
    "MX": "Mexico", "MY": "Malaysia", "MZ": "Mozambique",
    "NA": "Namibia", "NC": "New Caledonia", "NE": "Niger",
    "NF": "Norfolk Island", "NG": "Nigeria", "NI": "Nicaragua",
    "NL": "Netherlands", "NO": "Norway", "NP": "Nepal",
    "NR": "Nauru", "NU": "Niue", "NZ": "New Zealand",
    "OM": "Oman", "PA": "Panama", "PE": "Peru",
    "PF": "French Polynesia", "PG": "Papua New Guinea", "PH": "Philippines",
    "PK": "Pakistan", "PL": "Poland", "PM": "Saint Pierre and Miquelon",
    "PN": "Pitcairn", "PR": "Puerto Rico", "PS": "Palestine",
    "PT": "Portugal", "PW": "Palau", "PY": "Paraguay",
    "QA": "Qatar", "RE": "Réunion", "RO": "Romania",
    "RS": "Serbia", "RU": "Russia", "RW": "Rwanda",
    "SA": "Saudi Arabia", "SB": "Solomon Islands", "SC": "Seychelles",
    "SD": "Sudan", "SE": "Sweden", "SG": "Singapore",
    "SH": "Saint Helena", "SI": "Slovenia", "SJ": "Svalbard and Jan Mayen",
    "SK": "Slovakia", "SL": "Sierra Leone", "SM": "San Marino",
    "SN": "Senegal", "SO": "Somalia", "SR": "Suriname",
    "SS": "South Sudan", "ST": "São Tomé and Príncipe", "SV": "El Salvador",
    "SX": "Sint Maarten", "SY": "Syria", "SZ": "Eswatini",
    "TC": "Turks and Caicos Islands", "TD": "Chad", "TF": "French Southern Territories",
    "TG": "Togo", "TH": "Thailand", "TJ": "Tajikistan",
    "TK": "Tokelau", "TL": "Timor-Leste", "TM": "Turkmenistan",
    "TN": "Tunisia", "TO": "Tonga", "TR": "Turkey",
    "TT": "Trinidad and Tobago", "TV": "Tuvalu", "TW": "Taiwan",
    "TZ": "Tanzania", "UA": "Ukraine", "UG": "Uganda",
    "UM": "U.S. Outlying Islands", "US": "United States", "UY": "Uruguay",
    "UZ": "Uzbekistan", "VA": "Vatican City", "VC": "Saint Vincent and the Grenadines",
    "VE": "Venezuela", "VG": "British Virgin Islands", "VI": "U.S. Virgin Islands",
    "VN": "Vietnam", "VU": "Vanuatu", "WF": "Wallis and Futuna",
    "WS": "Samoa", "YE": "Yemen", "YT": "Mayotte",
    "ZA": "South Africa", "ZM": "Zambia", "ZW": "Zimbabwe"
}


def extract_country_code_and_name(country_value: str) -> Optional[tuple[str, str]]:
    """
    Extract country code and name from format 'code:name' or 'code:name:variant'
    
    Args:
        country_value: Country string in format like 'es:España' or 'en:United States'
        
    Returns:
        Tuple of (code, name) if format is valid, None otherwise
    """
    if not country_value or ':' not in country_value:
        return None
    
    parts = country_value.split(':', 1)  # Split only on first colon
    if len(parts) != 2:
        return None
    
    code = parts[0].strip().upper()
    name = parts[1].strip()
    
    if not code or not name:
        return None
    
    return (code, name)


def convert_to_english(country_value: str) -> Optional[str]:
    """
    Convert localized country name to English name
    
    Args:
        country_value: Country string like 'es:España'
        
    Returns:
        Converted string like 'es:Spain' or None if conversion not possible
    """
    result = extract_country_code_and_name(country_value)
    if not result:
        return None
    
    code, current_name = result
    
    # Check if country code exists in mapping
    if code not in COUNTRY_CODE_TO_ENGLISH:
        logger.debug(f"Unknown country code: {code}")
        return None
    
    english_name = COUNTRY_CODE_TO_ENGLISH[code]
    
    # Only convert if the current name is different from English name
    if current_name.lower() == english_name.lower():
        return None  # Already in English
    
    return f"{code.lower()}:{english_name}"


class CountryToEnglishConverter:
    """
    Handles database conversion operations for country column localization
    """
    
    def __init__(self, dry_run: bool = True):
        """
        Initialize the converter
        
        Args:
            dry_run: If True, only analyze data without making changes
        """
        self.dry_run = dry_run
        self.supabase = None
        self.stats = {
            'total_records': 0,
            'records_to_convert': 0,
            'records_already_english': 0,
            'records_unknown_format': 0,
            'records_unknown_code': 0,
            'records_updated': 0,
            'conversion_map': {},  # Track conversions: old -> new
            'errors': []
        }
    
    async def initialize(self) -> bool:
        """
        Initialize database connection
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            logger.info("Initializing database connection...")
            from supabase import create_client
            self.supabase = create_client(
                settings.supabase_url, 
                settings.supabase_service_role_key
            )
            logger.info("✅ Database connection established")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to initialize database: {e}")
            return False
    
    async def analyze_data(self) -> Dict[str, Any]:
        """
        Analyze the current state of country column in food_items table
        
        Returns:
            Dict containing analysis results
        """
        logger.info("🔍 Analyzing country column in food_items table...")
        
        try:
            # Get total count of food items with country values
            total_response = self.supabase.table("food_items").select(
                "id", 
                count="exact"
            ).not_.is_("country", "null").execute()
            
            self.stats['total_records'] = total_response.count or 0
            
            logger.info(f"📊 Total food items with country values: {self.stats['total_records']}")
            
            if self.stats['total_records'] == 0:
                logger.warning("⚠️  No food items with country values found in database")
                return self.stats
            
            # Get all food items with country values (handle pagination)
            logger.info("📋 Fetching food items with country values...")
            all_food_items = []
            page_size = 1000
            offset = 0
            
            while True:
                response = self.supabase.table("food_items").select(
                    "id, name, brand, country"
                ).not_.is_("country", "null").range(offset, offset + page_size - 1).execute()
                
                if not response.data:
                    break
                    
                all_food_items.extend(response.data)
                offset += page_size
                
                logger.info(f"📦 Retrieved {len(all_food_items)} food items so far...")
                
                if len(response.data) < page_size:
                    break
            
            food_items = all_food_items
            logger.info(f"📦 Retrieved {len(food_items)} food items total")
            
            # Analyze each item
            items_to_update = []
            items_already_english = []
            items_unknown_format = []
            items_unknown_code = []
            
            for item in food_items:
                country = item.get('country', '').strip()
                
                if not country:
                    continue
                
                # Try to convert to English
                converted = convert_to_english(country)
                
                if converted is None:
                    # Check if it's already in English or unknown format
                    result = extract_country_code_and_name(country)
                    if result:
                        code, name = result
                        if code in COUNTRY_CODE_TO_ENGLISH:
                            english_name = COUNTRY_CODE_TO_ENGLISH[code]
                            if name.lower() == english_name.lower():
                                items_already_english.append(item)
                            else:
                                items_unknown_code.append(item)
                        else:
                            items_unknown_code.append(item)
                    else:
                        items_unknown_format.append(item)
                else:
                    # Conversion possible
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': converted
                    })
                    
                    # Track conversion mapping
                    if country not in self.stats['conversion_map']:
                        self.stats['conversion_map'][country] = converted
            
            self.stats['records_to_convert'] = len(items_to_update)
            self.stats['records_already_english'] = len(items_already_english)
            self.stats['records_unknown_format'] = len(items_unknown_format)
            self.stats['records_unknown_code'] = len(items_unknown_code)
            
            # Store items to update for later use
            self.items_to_update = items_to_update
            
            # Log analysis results
            logger.info(f"📊 Analysis Results:")
            logger.info(f"  Records to convert: {self.stats['records_to_convert']}")
            logger.info(f"  Records already in English: {self.stats['records_already_english']}")
            logger.info(f"  Records with unknown format: {self.stats['records_unknown_format']}")
            logger.info(f"  Records with unknown country code: {self.stats['records_unknown_code']}")
            
            # Show conversion mappings
            if self.stats['conversion_map']:
                logger.info("🔄 Conversion mappings:")
                for old, new in list(self.stats['conversion_map'].items())[:20]:  # Show first 20
                    logger.info(f"  {old} → {new}")
                if len(self.stats['conversion_map']) > 20:
                    logger.info(f"  ... and {len(self.stats['conversion_map']) - 20} more")
            
            # Show some examples of items that will be updated
            if items_to_update:
                logger.info("📝 Sample items to be updated:")
                for i, item_update in enumerate(items_to_update[:10]):  # Show first 10
                    item_data = next(
                        (item for item in food_items if item['id'] == item_update['id']), 
                        None
                    )
                    if item_data:
                        logger.info(
                            f"  {i+1}. {item_data.get('name', 'Unknown')} "
                            f"(Brand: {item_data.get('brand', 'Unknown')}) "
                            f"[{item_update['old_country']} → {item_update['new_country']}]"
                        )
                if len(items_to_update) > 10:
                    logger.info(f"  ... and {len(items_to_update) - 10} more")
            
            return self.stats
            
        except Exception as e:
            error_msg = f"Error analyzing data: {e}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return self.stats
    
    async def convert_records(self) -> Dict[str, Any]:
        """
        Update food items with English country names
        
        Returns:
            Dict containing conversion results
        """
        if self.dry_run:
            logger.info("🔍 DRY RUN MODE - No records will be updated")
            return self.stats
        
        if not hasattr(self, 'items_to_update') or not self.items_to_update:
            logger.info("✅ No records need to be converted")
            return self.stats
        
        logger.info("🔄 Starting country name conversion to English...")
        
        try:
            updated_count = 0
            
            # Update records one by one
            for i, item_update in enumerate(self.items_to_update):
                try:
                    update_response = self.supabase.table("food_items").update({
                        'country': item_update['new_country']
                    }).eq('id', item_update['id']).execute()
                    
                    if update_response.data:
                        updated_count += 1
                    
                    # Log progress every 100 records
                    if (i + 1) % 100 == 0:
                        logger.info(f"📊 Updated {i + 1} of {len(self.items_to_update)} records...")
                        
                except Exception as e:
                    error_msg = f"Error updating record {item_update['id']}: {e}"
                    logger.error(error_msg)
                    self.stats['errors'].append(error_msg)
            
            self.stats['records_updated'] = updated_count
            logger.info(f"✅ Conversion completed. Updated {updated_count} records")
            
            return self.stats
            
        except Exception as e:
            error_msg = f"Error during conversion: {e}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return self.stats
    
    async def generate_report(self) -> str:
        """
        Generate a conversion report
        
        Returns:
            str: Formatted report
        """
        report = []
        report.append("=" * 60)
        report.append("COUNTRY TO ENGLISH CONVERSION REPORT")
        report.append("=" * 60)
        report.append(f"Timestamp: {datetime.now().isoformat()}")
        report.append(f"Mode: {'DRY RUN' if self.dry_run else 'LIVE CONVERSION'}")
        report.append("")
        
        report.append("📊 STATISTICS:")
        report.append(f"  Total records with country values: {self.stats['total_records']}")
        report.append(f"  Records to convert: {self.stats['records_to_convert']}")
        report.append(f"  Records already in English: {self.stats['records_already_english']}")
        report.append(f"  Records with unknown format: {self.stats['records_unknown_format']}")
        report.append(f"  Records with unknown country code: {self.stats['records_unknown_code']}")
        report.append(f"  Records updated: {self.stats['records_updated']}")
        report.append("")
        
        if self.stats['conversion_map']:
            report.append("🔄 CONVERSION MAPPINGS:")
            for old, new in sorted(self.stats['conversion_map'].items()):
                report.append(f"  {old} → {new}")
            report.append("")
        
        if self.stats['errors']:
            report.append("❌ ERRORS:")
            for error in self.stats['errors']:
                report.append(f"  - {error}")
            report.append("")
        
        # Calculate percentages
        if self.stats['total_records'] > 0:
            convert_percentage = (self.stats['records_to_convert'] / self.stats['total_records']) * 100
            updated_percentage = (
                (self.stats['records_updated'] / self.stats['total_records']) * 100
            ) if not self.dry_run else 0
            english_percentage = (self.stats['records_already_english'] / self.stats['total_records']) * 100
            
            report.append("📈 PERCENTAGES:")
            report.append(f"  Records to convert: {convert_percentage:.1f}%")
            if not self.dry_run:
                report.append(f"  Records updated: {updated_percentage:.1f}%")
            report.append(f"  Records already in English: {english_percentage:.1f}%")
            report.append("")
        
        report.append("=" * 60)
        
        return "\n".join(report)
    
    async def convert(self) -> bool:
        """
        Perform the complete conversion process
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # Initialize database connection
            if not await self.initialize():
                return False
            
            # Analyze current data
            await self.analyze_data()
            
            # Perform conversion
            await self.convert_records()
            
            # Generate and display report
            report = await self.generate_report()
            print("\n" + report)
            
            # Log final status
            if self.stats['errors']:
                logger.warning(f"⚠️  Conversion completed with {len(self.stats['errors'])} errors")
                return False
            else:
                logger.info("✅ Conversion completed successfully")
                return True
                
        except Exception as e:
            logger.error(f"❌ Conversion failed: {e}")
            return False


async def main():
    """
    Main function to run the country to English conversion
    """
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Convert localized country names to English names in food_items table"
    )
    parser.add_argument(
        "--dry-run", 
        action="store_true", 
        help="Analyze data without making changes"
    )
    parser.add_argument(
        "--confirm", 
        action="store_true", 
        help="Confirm that you want to update records"
    )
    
    args = parser.parse_args()
    
    # Determine if this is a dry run
    dry_run = args.dry_run or not args.confirm
    
    if not dry_run:
        print("⚠️  WARNING: This will permanently update records in your database!")
        print("   Make sure you have a backup before proceeding.")
        print("   Use --dry-run to analyze data without making changes.")
        print()
        
        if args.confirm:
            print("✅ Confirmation flag provided - proceeding with conversion...")
        else:
            confirm = input("Are you sure you want to proceed? (type 'yes' to confirm): ")
            if confirm.lower() != 'yes':
                print("❌ Operation cancelled")
                return
    
    # Create converter handler
    converter = CountryToEnglishConverter(dry_run=dry_run)
    
    # Run conversion
    success = await converter.convert()
    
    if success:
        print("\n✅ Country to English conversion completed successfully!")
    else:
        print("\n❌ Country to English conversion failed. Check the logs for details.")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())

