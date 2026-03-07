# Contributing to FusionNet Stat

Thank you for your interest in contributing! This document provides guidelines for contributors.

## Getting Started

### Prerequisites
- macOS 10.15 or later
- Xcode Command Line Tools
- Basic knowledge of Swift and macOS development

### Setup
1. Fork the repository
2. Clone your fork locally
3. Create a feature branch: `git checkout -b feature/your-feature-name`

## Development Guidelines

### Code Style
- Use 4 spaces for indentation
- Follow Swift naming conventions
- Add comments for complex logic
- Keep methods focused and small

### Testing
- Test changes on different macOS versions if possible
- Verify network monitoring works correctly
- Ensure menu bar functionality is intact
- Check that installation/uninstallation scripts work

### Before Submitting
1. Ensure your code builds without errors
2. Test the full installation process
3. Update documentation if needed
4. Commit messages should be clear and descriptive

## Areas for Contribution

### Potential Enhancements
- [ ] Graphical network usage history
- [ ] Support for multiple network interfaces
- [ ] Customizable speed test servers
- [ ] Dark mode support for menu
- [ ] Export network usage data
- [ ] Notification alerts for network issues
- [ ] Bandwidth usage caps with alerts
- [ ] Integration with network management tools

### Bug Fixes
- [ ] Test on various macOS versions
- [ ] Handle edge cases for network interfaces
- [ ] Improve error handling for network failures

## Submission Process

1. **Fork** the repository
2. **Create** a feature branch
3. **Make** your changes
4. **Test** thoroughly
5. **Commit** your changes with clear messages
6. **Push** to your fork
7. **Create** a Pull Request

### Pull Request Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Other

## Testing
- [ ] Tested on macOS version: _____
- [ ] Installation script tested
- [ ] Network monitoring verified
- [ ] Speed test functionality checked

## Checklist
- [ ] Code follows project style
- [ ] Self-review completed
- [ ] Documentation updated
```

## Questions?

Feel free to open an issue for any questions about contributing!
