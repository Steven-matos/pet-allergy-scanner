# 🚀 Full OpenPetFoodFacts Import Guide

## 📋 Overview

This guide will help you import **ALL** products from your OpenPetFoodFacts JSONL file into your enhanced database schema. The import process will extract comprehensive data including species information, allergens, nutritional data, and images.

## 🎯 What You'll Get

- **14,000+ pet food products** with comprehensive data
- **Species-specific analysis** (dog vs cat products)
- **Allergen detection** (fish, gluten, soy, milk, etc.)
- **Nutritional information** (protein, fat, fiber, calories)
- **Product images** (front, ingredients, nutrition labels)
- **Quality scoring** (data completeness 0.0-1.0)
- **Geographic coverage** (global with French focus)

## 🚀 Quick Start

### Option 1: Automated Full Import (Recommended)
```bash
# Run the automated full import script
python3 scripts/run_full_import.py

# For dry run (test mode - no data inserted)
python3 scripts/run_full_import.py --dry-run
```

### Option 2: Manual Step-by-Step
```bash
# 1. Count products in your file
python3 scripts/count_products.py

# 2. Apply database migration
psql -d snifftest -f migrations/enhance_food_items_table.sql

# 3. Run enhanced import with progress tracking
python3 scripts/enhanced_import_with_progress.py

# 4. Test the import
python3 scripts/test_import.py
```

## 📊 Expected Results

Based on your JSONL file analysis:
- **Total products**: ~14,000
- **Species distribution**: ~36% dog, ~27% cat, ~37% other
- **Processing time**: ~15-20 minutes
- **Database size increase**: ~7-10 MB
- **Success rate**: ~80-90% (high-quality data)

## 🔧 Configuration Options

### Batch Size
- **Default**: 500 products per batch
- **Smaller batches**: Better memory management, slower processing
- **Larger batches**: Faster processing, more memory usage

```bash
# Use smaller batches for limited memory
python3 scripts/enhanced_import_with_progress.py --batch-size 250

# Use larger batches for faster processing
python3 scripts/enhanced_import_with_progress.py --batch-size 1000
```

### Dry Run Mode
```bash
# Test the import without inserting data
python3 scripts/enhanced_import_with_progress.py --dry-run
```

## 📈 Progress Tracking

The enhanced import script provides real-time progress updates:

```
📊 Progress: 5,000/14,179 (35.2%) | Rate: 45.2 lines/sec | ETA: 3.2 min
📊 Progress: 10,000/14,179 (70.5%) | Rate: 48.1 lines/sec | ETA: 1.5 min
✅ Import completed in 18.3 minutes
📊 Final stats: 11,234 processed, 2,456 skipped, 489 errors
```

## 🎯 What Gets Imported

### Core Product Data
- **Name**: Product name (e.g., "Purina Pro Plan Adult")
- **Brand**: Manufacturer (e.g., "Purina", "Royal Canin")
- **Barcode**: Unique identifier
- **Category**: Product category

### Species & Life Stage
- **Species**: dog, cat, both, unknown
- **Life Stage**: puppy, kitten, adult, senior, all, unknown
- **Product Type**: dry, wet, treat, supplement, unknown

### Nutritional Data
- **Calories per 100g**: Energy content
- **Protein %**: Protein percentage
- **Fat %**: Fat percentage
- **Fiber %**: Fiber percentage
- **Moisture %**: Water content
- **Ash %**: Mineral content

### Allergen & Safety
- **Allergens**: Fish, gluten, soy, milk, eggs, etc.
- **Additives**: Preservatives, colorants, etc.
- **Vitamins**: Vitamin information
- **Minerals**: Mineral content

### Images & Media
- **Front Image**: Product front photo
- **Ingredients Image**: Ingredients list photo
- **Nutrition Image**: Nutrition facts photo

### Quality & Source
- **Data Completeness**: 0.0-1.0 quality score
- **External Source**: openpetfoodfacts
- **Last Updated**: Timestamp from source

## 🔍 Monitoring the Import

### Real-time Progress
The import script shows:
- **Current progress**: X/Y products processed
- **Processing rate**: Products per second
- **ETA**: Estimated time remaining
- **Batch updates**: Every 10 seconds or 1000 products

### Log Files
- **Info logs**: Progress updates and statistics
- **Warning logs**: Data quality issues
- **Error logs**: Processing errors and failures

### Database Monitoring
```sql
-- Check import progress
SELECT COUNT(*) FROM food_items;

-- Check data quality distribution
SELECT 
    CASE 
        WHEN data_completeness >= 0.8 THEN 'High Quality'
        WHEN data_completeness >= 0.5 THEN 'Medium Quality'
        ELSE 'Low Quality'
    END as quality_level,
    COUNT(*) as count
FROM food_items 
GROUP BY quality_level;

-- Check species distribution
SELECT species, COUNT(*) as count 
FROM food_items 
GROUP BY species;
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Database Connection Error
```bash
# Check database connection
psql -d snifftest -c "SELECT 1;"
```

#### 2. Memory Issues
```bash
# Use smaller batch size
python3 scripts/enhanced_import_with_progress.py --batch-size 250
```

#### 3. Disk Space
```bash
# Check available disk space
df -h
```

#### 4. Import Interruption
```bash
# Resume import (will skip duplicates)
python3 scripts/enhanced_import_with_progress.py
```

### Performance Optimization

#### For Large Files
```bash
# Use smaller batches
python3 scripts/enhanced_import_with_progress.py --batch-size 250

# Monitor system resources
top -p $(pgrep -f enhanced_import)
```

#### For Fast Processing
```bash
# Use larger batches (if you have enough memory)
python3 scripts/enhanced_import_with_progress.py --batch-size 1000
```

## ✅ Verification

### Test Import Results
```bash
# Run the test script
python3 scripts/test_import.py
```

### Manual Verification
```sql
-- Check total count
SELECT COUNT(*) FROM food_items;

-- Check sample products
SELECT name, brand, species, product_type, data_completeness 
FROM food_items 
LIMIT 10;

-- Check data quality
SELECT 
    AVG(data_completeness) as avg_quality,
    MIN(data_completeness) as min_quality,
    MAX(data_completeness) as max_quality
FROM food_items;
```

## 🎉 Success Criteria

Your import is successful when:
- ✅ **Total products**: 10,000+ imported
- ✅ **Success rate**: 80%+ processed successfully
- ✅ **Data quality**: Average completeness > 0.4
- ✅ **Species distribution**: Both dog and cat products present
- ✅ **Images**: 70%+ have product images
- ✅ **Nutritional data**: 40%+ have protein/fat data

## 🚀 Next Steps

After successful import:
1. **Test your app** with the new data
2. **Update your API** to use the enhanced fields
3. **Implement species-specific filtering**
4. **Add allergen detection features**
5. **Create quality-based recommendations**

---

**🎯 Ready to import ALL your OpenPetFoodFacts data? Run the automated script and watch your Pet Allergy Scanner app transform into a comprehensive pet nutrition platform!**
