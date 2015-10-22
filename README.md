# Monitoring Google Drive

Search/List Google Drive's Documents on your domain.

Requirements:
- Ruby 2.0.0 or higher

# Installation

This script is originated by google-drive-permission-search.

https://github.com/morimorihoge/google-drive-permission-search

For installation:

```
bundle
```

# Usage

```
bundle exec ./monitoring-google-drive.rb --verbose --issuer 999999999999-0123456789abcdefghijklmnopqrstuv@developer.gserviceaccount.com --admin admin@example.com
```

# Options

- -v, --verbose: output debug messages
- --admin <email>: domain administrator account
- --owner <email>: owner account
