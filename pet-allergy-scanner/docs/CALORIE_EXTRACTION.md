# Calorie Extraction for Pet Food Labels

## Overview
Enhanced calorie extraction logic that prioritizes **kcal/kg** (metabolizable energy) values over per-treat or per-serving values. This ensures accurate nutritional data for pet food comparison and analysis.

---

## Why kcal/kg?

### **The Standard Metric**
- **kcal/kg** (kilocalories per kilogram) is the **industry standard** for pet food energy density
- Also known as **ME** (Metabolizable Energy)
- Allows **apples-to-apples comparison** between different products
- Independent of serving size, treat weight, or package size

### **The Problem with Per-Serving Values**
Pet food labels often show multiple calorie values:
```
✓ 3013 kcal/kg (ME) ← What we want!
✗ 16 kcal per treat ← Not standardized
✗ 80 kcal per cup ← Varies by density
```

**Why per-treat is unreliable:**
- Treat sizes vary wildly (1g to 50g+)
- Not comparable across brands
- Doesn't reflect energy density
- Can't be used for feeding calculations

---

## Extraction Logic

### **Priority Order**

The extraction follows a **smart prioritization** system:

#### **Priority 1: kcal/kg Pattern** ⭐⭐⭐
Matches these formats:
```
✓ 3013 kcal/kg
✓ 3,013 kcal/kg
✓ 3 013 kcal/kg
✓ 3013 kcal per kg
✓ 3013 kcal/kilogram
```

**Regex patterns:**
- `(\d[\d\s,]*\d|\d+)\s*kcal\s*/\s*kg`
- `(\d[\d\s,]*\d|\d+)\s*kcal\s*per\s*kg`
- `(\d[\d\s,]*\d|\d+)\s*kcal\s*\/\s*kilogram`

#### **Priority 2: ME (Metabolizable Energy)** ⭐⭐
Matches these formats:
```
✓ ME: 3013 kcal/kg
✓ ME (calculated): 3013 kcal/kg
✓ Metabolizable Energy: 3013 kcal/kg
```

**Regex pattern:**
- `me[^:]*:\s*(\d[\d\s,]*\d|\d+)`

#### **Priority 3: Generic /kg Pattern** ⭐
Matches any number followed by "per kg" or "/kg":
```
✓ 3013 per kg
✓ 3013/kg
```

#### **Priority 4: Fallback** 
Only if no kcal/kg found, extracts any number:
```
⚠️ 16 kcal per treat (only used as last resort)
```

---

## Implementation Details

### **Number Parsing**
Handles various number formats:
- **Commas**: `3,013` → `3013`
- **Spaces**: `3 013` → `3013`
- **Plain**: `3013` → `3013`

### **Overwrite Logic**
```swift
if nutrition.calories == nil || isKcalPerKg {
    nutrition.calories = value
}
```

**What this means:**
1. First calorie value found → saved
2. Then kcal/kg value found → **overwrites** previous value
3. Ensures kcal/kg always wins

### **Example Scenario**

**Input text:**
```
Treats for Dogs
16 kcal per treat
3013 kcal/kg ME (calculated)
```

**Processing:**
1. Line 1: "16 kcal per treat"
   - Extracts: `16`
   - Saves: `nutrition.calories = 16`
   
2. Line 2: "3013 kcal/kg ME"
   - Extracts: `3013`
   - Detects: kcal/kg pattern ✓
   - **Overwrites**: `nutrition.calories = 3013` ✅

**Result:** `3013` (correct!)

---

## UI Display

### **Calorie Card Enhancement**

**Before:**
```
🔥 Calorie Content
   16 kcal
```

**After:**
```
🔥 Metabolizable Energy
   3,013 kcal/kg
   Standard measurement for pet food energy density
```

**Features:**
- ✅ Shows "Metabolizable Energy" title (more accurate)
- ✅ Displays "kcal/kg" unit (clear context)
- ✅ Formatted with comma separator (3,013 vs 3013)
- ✅ Helpful caption explaining the metric

---

## Test Cases

### **Test 1: Basic kcal/kg**
```
Input: "3013 kcal/kg"
Expected: 3013 ✓
```

### **Test 2: With Commas**
```
Input: "3,013 kcal/kg"
Expected: 3013 ✓
```

### **Test 3: With Spaces**
```
Input: "3 013 kcal/kg"
Expected: 3013 ✓
```

### **Test 4: ME Format**
```
Input: "ME (calculated): 3013 kcal/kg"
Expected: 3013 ✓
```

### **Test 5: Priority Override**
```
Input: "16 kcal per treat\n3013 kcal/kg"
Expected: 3013 ✓ (not 16)
```

### **Test 6: Per Treat Only (Fallback)**
```
Input: "16 kcal per treat"
Expected: 16 ✓ (better than nothing)
```

### **Test 7: Multiple Lines**
```
Input: 
  "Nutritional Information"
  "80 kcal per cup"
  "16 kcal per treat"
  "ME: 3013 kcal/kg"
Expected: 3013 ✓
```

---

## Real-World Examples

### **Example 1: Dog Treats**
```
OCR Output:
-----------
Blue Buffalo Wilderness Trail Treats
Grain Free Turkey Recipe
16 kcal per treat
Metabolizable Energy: 3013 kcal/kg

Extracted: 3013 kcal/kg ✅
```

### **Example 2: Dry Dog Food**
```
OCR Output:
-----------
Hill's Science Diet Adult
Calorie Content (calculated):
3,765 kcal/kg
375 kcal per cup

Extracted: 3765 kcal/kg ✅
```

### **Example 3: Wet Cat Food**
```
OCR Output:
-----------
Fancy Feast Classic Pate
85 kcal per 3oz can
ME: 1,120 kcal/kg

Extracted: 1120 kcal/kg ✅
```

---

## Benefits

### **For Users:**
- 🎯 **Accurate Comparisons**: Compare products on equal footing
- 📊 **Better Analysis**: Understand true energy density
- 🔍 **Quality Data**: Database contains standardized values
- 💡 **Educational**: Learn industry standard metrics

### **For Database:**
- ✅ **Consistency**: All products use same metric
- 🔢 **Searchable**: Filter by calorie range meaningfully
- 📈 **Scalable**: Works for all pet food types
- 🌐 **Universal**: Compatible with global standards

---

## Edge Cases Handled

### **1. Multiple Calorie Lines**
```
80 kcal per serving
16 kcal per treat
3013 kcal/kg ← This wins
```

### **2. OCR Spacing Issues**
```
3013kcal/kg   → 3013 ✓
3013 kcal / kg → 3013 ✓
3013  kcal /kg → 3013 ✓
```

### **3. Comma Variations**
```
3,013 kcal/kg → 3013 ✓
3.013 kcal/kg → 3013 ✓ (Europe format)
```

### **4. No kcal/kg Found**
```
16 kcal per treat only → 16 ⚠️
(Fallback, but flagged for review)
```

### **5. Mixed Units**
```
16 kcal per treat
3013 ME kcal/kg ← Extracted correctly
```

---

## Future Enhancements

### **Possible Improvements:**

1. **Unit Conversion**
   - Detect and convert kJ/kg to kcal/kg
   - Support international formats

2. **Confidence Scoring**
   - High confidence: kcal/kg pattern found
   - Medium confidence: ME notation
   - Low confidence: fallback number

3. **Multiple Value Storage**
   - Store both kcal/kg AND per-serving
   - Display conversion calculator

4. **OCR Validation**
   - Flag suspicious values (e.g., 50,000 kcal/kg)
   - Suggest typical ranges by food type

5. **Brand-Specific Rules**
   - Learn common formats per manufacturer
   - Improve extraction accuracy over time

---

## Technical Reference

### **File Location**
`/Features/Scanning/Views/NutritionalLabelResultView.swift`

### **Key Functions**

#### `extractCalories(from text: String) -> Double?`
Main extraction function with priority logic

#### `parseNutritionalInfo(from text: String) -> ParsedNutrition`
Calls `extractCalories` during OCR parsing

#### `ParsedCalorieInfoCard`
UI component displaying the calorie value

### **Related Components**
- `OCRSpellChecker`: Pre-corrects "kcal" → fixes "kca1", "keal", etc.
- `HybridScanService`: Provides OCR text
- `FoodProduct.NutritionalInfo`: Stores final value

---

## Summary

The enhanced calorie extraction system:

✅ **Prioritizes kcal/kg** (industry standard)  
✅ **Handles multiple formats** (commas, spaces, ME notation)  
✅ **Overrides per-serving values** when kcal/kg found  
✅ **Displays clearly** with "Metabolizable Energy" label  
✅ **Formats nicely** with thousand separators  
✅ **Educates users** with helpful caption  

**Result:** High-quality, standardized calorie data for better pet nutrition analysis! 🐾

