# Contributing to Concierge API

Thank you for your interest in contributing to the Concierge API! This document provides guidelines for contributing to the project.

## 🚀 Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/concierge-api.git
   cd concierge-api
   ```
3. **Create a virtual environment**:
   ```bash
   python3 -m venv mysql_api_venv
   source mysql_api_venv/bin/activate
   ```
4. **Install dependencies**:
   ```bash
   pip install -r mysql_api/requirements.txt
   pip install pytest flake8 black isort
   ```

## 🔧 Development Workflow

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our coding standards

3. **Run tests**:
   ```bash
   pytest tests/
   ```

4. **Check code formatting**:
   ```bash
   black mysql_api/
   isort mysql_api/
   flake8 mysql_api/
   ```

5. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Add feature: your descriptive message"
   ```

6. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request** on GitHub

## 📋 Coding Standards

- **Python Style**: Follow PEP 8, enforced by `flake8`
- **Code Formatting**: Use `black` for automatic formatting
- **Import Sorting**: Use `isort` for consistent import ordering
- **Documentation**: Add docstrings to all functions and classes
- **Type Hints**: Use type hints where appropriate

## 🧪 Testing

- Write tests for new features in the `tests/` directory
- Ensure all tests pass before submitting a PR
- Aim for good test coverage on new code

## 📝 Commit Messages

Use clear, descriptive commit messages:
- `feat: add new entity validation endpoint`
- `fix: resolve database connection timeout issue`
- `docs: update API documentation for v3.1`
- `test: add unit tests for curation endpoints`

## 🐛 Reporting Issues

When reporting issues, please include:
- Python version
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Error messages (if any)

## 💡 Feature Requests

Before requesting a feature:
1. Check if it already exists in the issues
2. Provide a clear use case
3. Explain why it would benefit other users

## 📚 Documentation

- Update documentation for any API changes
- Add examples for new endpoints
- Keep README.md current

## 🔒 Security

If you discover a security vulnerability:
- **Do not** open a public issue
- Email the maintainer directly
- Provide detailed information about the vulnerability

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## ❓ Questions?

Feel free to open an issue for questions about contributing or reach out to the maintainers.

Thank you for contributing! 🎉