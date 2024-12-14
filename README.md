# FLC (File License Control)

A macOS application for managing and validating AD (Active Directory) and HR data imports.

## Features

### Data Import
- Import AD and HR data from Excel files
- Real-time validation during import
- Progress tracking with detailed status updates
- Support for large datasets

### Data Validation
- Automatic validation of required fields
- Duplicate detection
- Invalid record identification
- Separate views for valid, invalid, and duplicate records
- Search functionality across all record types

### Database Management
- Efficient batch processing (5000 records per batch)
- Progress tracking for database operations
- Duplicate handling
- SQLite database with GRDB integration

### Export Functionality
- Export invalid and duplicate records to CSV
- Detailed error reporting
- Maintains original data context

## System Requirements

- macOS 11.0 or later
- Xcode 15.0 or later (for development)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/Miraclo1970/FLC.git
```

2. Open `FLC.xcodeproj` in Xcode

3. Build and run the project

## Usage

1. **Login**
   - Use provided credentials to access the system
   - Different access levels: Admin, Manager, User

2. **Import Data**
   - Select data type (AD or HR)
   - Choose Excel file for import
   - Monitor import progress

3. **Validate Data**
   - Review validation results in separate tabs
   - Search through records
   - Export invalid/duplicate records if needed

4. **Save to Database**
   - Save valid records to database
   - Monitor save progress
   - View success/error messages

## Architecture

- SwiftUI-based user interface
- MVVM architecture
- GRDB for database operations
- Batch processing for large datasets
- Asynchronous operations with progress tracking

## Version History

### v0.1 (Current)
- Initial stable release
- Basic functionality implemented:
  - Login system
  - Data import
  - Validation
  - Database operations
  - Export functionality

## Contributing

This is a private repository. Contact the repository owner for contribution guidelines.

## License

Proprietary software. All rights reserved.

## Contact

For support or inquiries, please contact the repository owner. 