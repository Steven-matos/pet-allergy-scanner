# SniffTest API Test Suite

Organized test suite for the SniffTest API server.

## 📁 Test Structure

```
tests/
├── security/           # Security-related tests
│   ├── test_security.py
│   └── security_audit.py
├── nutrition/          # Nutrition-related tests
│   └── test_advanced_nutrition.py
├── notifications/      # Notification tests
│   ├── test_apn.py
│   ├── quick_apn_test.py
│   └── simple_apn_test.py
├── database/           # Database tests
│   └── test_food_items_policies.py
├── utils/              # Utility scripts
│   ├── cleanup_logs.py
│   └── debug_connection.py
├── unit/               # Unit tests
│   └── shared/
│       ├── test_pet_authorization.py
│       └── test_user_metadata_mapper.py
├── integration/        # Integration tests
├── run_tests.py        # Test runner
└── README.md           # This file
```

## 🚀 Running Tests

### Run All Tests
```bash
python tests/run_tests.py
```

### Run Specific Categories
```bash
# Security tests
python tests/run_tests.py security

# Nutrition tests
python tests/run_tests.py nutrition

# Notification tests
python tests/run_tests.py notifications

# Database tests
python tests/run_tests.py database

# Unit tests
python tests/run_tests.py unit

# Integration tests
python tests/run_tests.py integration
```

### Run with pytest directly
```bash
# All tests
pytest tests/ -v

# Specific category
pytest tests/security/ -v
pytest tests/nutrition/ -v
```

## 📋 Test Categories

### 🔒 Security Tests (`tests/security/`)
- **test_security.py**: Security validation tests
- **security_audit.py**: Security audit script

### 🥗 Nutrition Tests (`tests/nutrition/`)
- **test_advanced_nutrition.py**: Advanced nutrition analysis tests

### 📱 Notification Tests (`tests/notifications/`)
- **test_apn.py**: Push notification tests
- **quick_apn_test.py**: Quick APN test
- **simple_apn_test.py**: Simple APN test

### 🗄️ Database Tests (`tests/database/`)
- **test_food_items_policies.py**: Database policy tests

### 🧪 Unit Tests (`tests/unit/`)
- **shared/**: Unit tests for shared services
  - **test_pet_authorization.py**: Pet authorization tests
  - **test_user_metadata_mapper.py**: User metadata mapper tests

### 🔗 Integration Tests (`tests/integration/`)
- End-to-end integration tests (to be added)

### 🛠️ Utility Scripts (`tests/utils/`)
- **cleanup_logs.py**: Log cleanup utility
- **debug_connection.py**: Connection debugging script

## 🎯 Best Practices

1. **Test Organization**: Tests are organized by functionality
2. **Naming Convention**: Test files start with `test_`
3. **Unit Tests**: Focus on individual components
4. **Integration Tests**: Test component interactions
5. **Utility Scripts**: Development and debugging tools

## 📊 Test Coverage

- **Security**: Input validation, authentication, authorization
- **Nutrition**: Advanced analytics, weight tracking, trends
- **Notifications**: Push notifications, APN functionality
- **Database**: Policies, RLS, data integrity
- **Unit**: Individual service testing
- **Integration**: End-to-end workflows

## 🔧 Development

When adding new tests:
1. Place tests in the appropriate category folder
2. Follow naming convention: `test_*.py`
3. Add proper docstrings and comments
4. Update this README if adding new categories
