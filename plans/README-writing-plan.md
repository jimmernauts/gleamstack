# README Writing Plan

## Project Overview
**Mealstack** - A recipe management and meal planning application built with Gleam

### Key Features Identified
- Recipe management with CRUD operations
- Meal planning with weekly calendar view
- Shopping list generation from meal plans
- Recipe import from URLs via web scraping
- OCR recipe scanning capabilities (WIP)
- Tag-based recipe categorization
- PWA capabilities

### Technology Stack
- **Frontend**: Gleam (compiles to JavaScript) with Lustre framework
- **Database**: InstantDB (real-time database)
- **Styling**: TailwindCSS
- **Build Tool**: Vite
- **Runtime**: Bun
- **Server**: Gleam with Glen framework (recipe scraping service)

## README Structure Plan

### 1. Header & Tech Stack Section
- Project name and description
- Technology stack: Gleam + Lustre (frontend), InstantDB (database), Gleam + Glen (server), Vite/Bun (build), TailwindCSS (styling)

### 2. Getting Started Section
#### Prerequisites
- Gleam compiler
- Bun runtime
- Node.js (for some dependencies)

#### Installation
```bash
# Clone the repository
git clone <repo-url>
cd gleamstack

# Install dependencies
bun install

# Setup environment
cp client/.env.example client/.env
# Edit .env with InstantDB credentials
```

#### Development
```bash
# Start client development server
bun run vite dev

# Start server (for recipe scraping)
cd server
bun run start
```

### 3. Configuration Section
- InstantDB setup
- Environment variables
- API keys for OCR (optional)

### 4. Project Structure
```
gleamstack/
├── client/          # Gleam frontend application
│   ├── src/         # Source code
│   │   ├── pages/   # Page components
│   │   ├── components/ # Shared components
│   │   └── lib/     # Utility modules
│   ├── gleam.toml   # Gleam configuration
│   └── package.json # Node dependencies
├── server/          # Recipe scraping service
│   ├── gleam.toml   # Server configuration
│   └── src/         # Server source code
├── common/          # Shared code (if any)
└── plans/           # Project plans and documentation
```

## Content to Gather/Finalize

### Missing Information Needed
1. **Repository URL** - github.com/jimmernauts/gleamstack
2. **Live Demo URL** - gleamstack.pages.dev
3. **Screenshots** - remove this 
4. **Environment Variables** - remove this
5. **API Setup** - InstantDB is configured using the .env file and the src/instant.schema.ts file in the client directory
6. **License** - remove this
7. **Contributing Guidelines** - remove this

### Technical Details to Verify
1. Exact command for server startup - cd server && gleam run
2. Full list of environment variables - remove this
3. Testing commands and framework used - make this a stub, we will work on it together
4. Build/deployment process - make this a stub, we will work on it together
5. Database schema documentation - make this a stub, we will work on it together

### Next Steps After Plan Approval
1. Gather missing information
2. Take app screenshots - don't
3. Write each section following the structure
4. Add code examples and commands - don't
5. Review and refine content
6. Add visual elements (badges, screenshots) - don't

## Notes
- The project is a monorepo with client and server components
- Client is a Gleam SPA using Lustre framework
- Server provides recipe scraping functionality
- Uses InstantDB for data persistence
- Built with modern functional programming principles
- Active development with several features in progress
