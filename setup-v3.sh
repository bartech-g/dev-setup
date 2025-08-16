#!/bin/bash

# Debian Developer Environment Setup Script
# Run with: bash setup-dev-env.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}===================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as a regular user."
   exit 1
fi

print_header "Starting Debian Developer Environment Setup"

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
print_status "Installing essential packages..."
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    cmake \
    gettext \
    ninja-build \
    python3 \
    python3-pip \
    ripgrep \
    fd-find \
    fzf \
    tree \
    htop \
    neofetch \
    zsh \
    tmux \
    jq \
    bat \
    exa

# Install latest Neovim
print_header "Installing Latest Neovim"
print_status "Downloading and installing Neovim AppImage..."
cd /tmp

# Download the correct AppImage filename
wget -O nvim-linux-x86_64.appimage https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
chmod u+x nvim-linux-x86_64.appimage

# Try to run AppImage directly first
if ./nvim-linux-x86_64.appimage --version &>/dev/null; then
    print_status "FUSE is available, installing AppImage directly..."
    sudo mv nvim-linux-x86_64.appimage /usr/local/bin/nvim
else
    print_warning "FUSE not available, extracting AppImage..."
    ./nvim-linux-x86_64.appimage --appimage-extract
    sudo mv squashfs-root /opt/nvim
    sudo ln -sf /opt/nvim/usr/bin/nvim /usr/local/bin/nvim
    rm -f nvim-linux-x86_64.appimage
fi

# Create symlink for system-wide access
sudo ln -sf /usr/local/bin/nvim /usr/bin/nvim

print_status "Neovim installed successfully!"
nvim --version

# Install NVM (Node Version Manager)
print_header "Installing NVM and Node.js"
print_status "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Source nvm for current session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Install latest LTS Node.js
print_status "Installing Node.js LTS via NVM..."
nvm install --lts
nvm use --lts
nvm alias default node

print_status "Node.js version: $(node --version)"
print_status "npm version: $(npm --version)"

# Install TypeScript and related tools globally
print_status "Installing TypeScript development tools..."
npm install -g typescript @types/node ts-node nodemon eslint prettier

# Install Oh My Zsh
print_header "Installing Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    print_status "Oh My Zsh installed!"
else
    print_warning "Oh My Zsh already installed, skipping..."
fi

# Install Zsh plugins
print_status "Installing Zsh plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || print_warning "zsh-autosuggestions already exists"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || print_warning "zsh-syntax-highlighting already exists"
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions 2>/dev/null || print_warning "zsh-completions already exists"

# Configure .zshrc
print_status "Configuring Zsh..."
cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(
    git
    docker
    docker-compose
    npm
    node
    nvm
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
)

source $ZSH/oh-my-zsh.sh

# NVM configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# User configuration
export EDITOR='nvim'
export VISUAL='nvim'

# Aliases
alias vim='nvim'
alias vi='nvim'
alias ll='exa -la'
alias ls='exa'
alias cat='batcat'
alias find='fd'
alias grep='rg'

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Auto-load .nvmrc files
autoload -U add-zsh-hook
load-nvmrc() {
  local nvmrc_path="$(nvm_find_nvmrc)"
  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc
EOF

# Install LazyVim
print_header "Installing LazyVim"
print_status "Backing up existing Neovim config (if any)..."
[ -d ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)
[ -d ~/.local/share/nvim ] && mv ~/.local/share/nvim ~/.local/share/nvim.backup.$(date +%Y%m%d_%H%M%S)

print_status "Cloning LazyVim starter config..."
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

# Configure LazyVim for TypeScript
print_status "Configuring LazyVim for TypeScript development..."
mkdir -p ~/.config/nvim/lua/plugins

# TypeScript configuration
cat > ~/.config/nvim/lua/plugins/typescript.lua << 'EOF'
return {
  -- TypeScript support
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ts_ls = {},
        eslint = {},
      },
    },
  },
  
  -- Better TypeScript experience
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    opts = {},
  },

  -- Formatting and linting
  {
    "nvimtools/none-ls.nvim",
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.formatting.prettier)
      table.insert(opts.sources, nls.builtins.diagnostics.eslint_d)
      table.insert(opts.sources, nls.builtins.code_actions.eslint_d)
    end,
  },

  -- Package.json support
  {
    "vuki656/package-info.nvim",
    dependencies = "MunifTanjim/nui.nvim",
    config = true,
    ft = "json",
  },
}
EOF

# Additional useful plugins
cat > ~/.config/nvim/lua/plugins/extras.lua << 'EOF'
return {
  -- File explorer enhancement
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },

  -- Git integration
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
    },
  },

  -- Better terminal
  {
    "akinsho/toggleterm.nvim",
    config = true,
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
    },
  },

  -- Markdown preview
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && npm install",
    ft = "markdown",
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreview<cr>", desc = "Markdown Preview" },
    },
  },

  -- REST client
  {
    "rest-nvim/rest.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    ft = "http",
    keys = {
      { "<leader>rr", "<cmd>Rest run<cr>", desc = "Run REST request" },
    },
  },

  -- Auto-detect project root
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup({
        detection_methods = { "pattern" },
        patterns = { ".git", "package.json", "tsconfig.json", ".nvmrc" },
      })
    end,
  },
}
EOF

# Install Docker
print_header "Installing Docker"
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Install additional developer tools
print_header "Installing Additional Developer Tools"

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh

# Install LazyGit
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm lazygit lazygit.tar.gz

# Install Starship prompt
curl -sS https://starship.rs/install.sh | sh -s -- -y

# Add starship to zshrc
echo 'eval "$(starship init zsh)"' >> ~/.zshrc

# Create a sample TypeScript project with NVM support
print_header "Creating Sample TypeScript Project"
mkdir -p ~/projects/typescript-starter
cd ~/projects/typescript-starter

# Create .nvmrc for Node.js version management
echo "lts/*" > .nvmrc

cat > package.json << 'EOF'
{
  "name": "typescript-starter",
  "version": "1.0.0",
  "description": "A TypeScript starter project with modern tooling",
  "main": "dist/index.js",
  "scripts": {
    "start": "node dist/index.js",
    "dev": "nodemon src/index.ts",
    "build": "tsc",
    "clean": "rm -rf dist",
    "lint": "eslint src/**/*.ts",
    "lint:fix": "eslint src/**/*.ts --fix",
    "format": "prettier --write src/**/*.ts",
    "type-check": "tsc --noEmit",
    "test": "echo \"Add your test command here\" && exit 0"
  },
  "keywords": ["typescript", "nodejs", "starter"],
  "author": "",
  "license": "MIT",
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "eslint": "^8.0.0",
    "nodemon": "^3.0.0",
    "prettier": "^3.0.0",
    "ts-node": "^10.0.0",
    "typescript": "^5.0.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "removeComments": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "moduleResolution": "node",
    "allowSyntheticDefaultImports": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
EOF

cat > .eslintrc.json << 'EOF'
{
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "extends": [
    "eslint:recommended",
    "@typescript-eslint/recommended"
  ],
  "parserOptions": {
    "ecmaVersion": 2022,
    "sourceType": "module"
  },
  "rules": {
    "@typescript-eslint/no-unused-vars": "error",
    "@typescript-eslint/explicit-function-return-type": "warn"
  }
}
EOF

cat > .prettierrc << 'EOF'
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 80,
  "tabWidth": 2
}
EOF

cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/

# Build outputs
dist/
build/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Editor directories and files
.vscode/
.idea/
*.swp
*.swo
*~

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF

mkdir -p src
cat > src/index.ts << 'EOF'
interface User {
  readonly id: number;
  name: string;
  email: string;
  createdAt: Date;
}

class UserService {
  private users: User[] = [];
  private nextId: number = 1;

  public addUser(userData: Omit<User, 'id' | 'createdAt'>): User {
    const user: User = {
      id: this.nextId++,
      name: userData.name,
      email: userData.email,
      createdAt: new Date(),
    };
    
    this.users.push(user);
    console.log(`✅ User ${user.name} added successfully!`);
    return user;
  }

  public getUser(id: number): User | undefined {
    return this.users.find((user) => user.id === id);
  }

  public getAllUsers(): readonly User[] {
    return [...this.users];
  }

  public getUserByEmail(email: string): User | undefined {
    return this.users.find((user) => user.email === email);
  }

  public updateUser(id: number, updates: Partial<Pick<User, 'name' | 'email'>>): User | null {
    const userIndex = this.users.findIndex((user) => user.id === id);
    if (userIndex === -1) return null;

    this.users[userIndex] = { ...this.users[userIndex], ...updates };
    console.log(`✅ User ${id} updated successfully!`);
    return this.users[userIndex];
  }

  public deleteUser(id: number): boolean {
    const userIndex = this.users.findIndex((user) => user.id === id);
    if (userIndex === -1) return false;

    this.users.splice(userIndex, 1);
    console.log(`🗑️  User ${id} deleted successfully!`);
    return true;
  }

  public getUserCount(): number {
    return this.users.length;
  }
}

// Example usage
function main(): void {
  console.log('🚀 Welcome to your TypeScript development environment!');
  console.log(`📦 Node.js version: ${process.version}`);
  
  const userService = new UserService();
  
  // Add some sample users
  const user1 = userService.addUser({
    name: 'John Doe',
    email: 'john@example.com',
  });
  
  const user2 = userService.addUser({
    name: 'Jane Smith',
    email: 'jane@example.com',
  });

  // Demonstrate functionality
  console.log('\n📊 Current users:');
  console.log(userService.getAllUsers());
  
  console.log(`\n👥 Total users: ${userService.getUserCount()}`);
  
  // Update a user
  userService.updateUser(user1.id, { name: 'John Updated' });
  
  // Find user by email
  const foundUser = userService.getUserByEmail('jane@example.com');
  console.log('\n🔍 Found user by email:', foundUser);
}

// Run the main function
main();
EOF

# Create README for the project
cat > README.md << 'EOF'
# TypeScript Starter Project

A modern TypeScript development setup with all the essentials.

## Features

- ✅ TypeScript with strict configuration
- ✅ ESLint for code linting
- ✅ Prettier for code formatting
- ✅ Nodemon for development
- ✅ NVM for Node.js version management
- ✅ Git configuration ready

## Getting Started

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build project
npm run build

# Lint code
npm run lint

# Format code
npm run format
```

## Node.js Version

This project uses the LTS version of Node.js specified in `.nvmrc`. When you navigate to this directory, NVM will automatically switch to the correct version.

## Scripts

- `npm run dev` - Start development server with hot reload
- `npm run build` - Build for production
- `npm run start` - Run production build
- `npm run lint` - Check code with ESLint
- `npm run lint:fix` - Fix ESLint issues automatically
- `npm run format` - Format code with Prettier
- `npm run type-check` - Check TypeScript types without building
EOF

# Install dependencies for the sample project
print_status "Installing project dependencies..."
npm install

cd ~

# Final message
print_header "Setup Complete!"
echo ""
print_status "🎉 Your Debian development environment has been set up successfully!"
echo ""
print_status "What's been installed:"
echo "  ✅ Latest Neovim with LazyVim (TypeScript configured)"
echo "  ✅ Oh My Zsh with useful plugins"
echo "  ✅ NVM (Node Version Manager) with Node.js LTS"
echo "  ✅ TypeScript development tools"
echo "  ✅ Docker and Docker Compose"
echo "  ✅ GitHub CLI (gh)"
echo "  ✅ LazyGit"
echo "  ✅ Starship prompt"
echo "  ✅ Developer tools: ripgrep, fd, fzf, bat, exa, htop, tree"
echo ""
print_warning "⚠️  Important next steps:"
echo "  1. Restart your terminal or run: exec zsh"
echo "  2. Log out and log back in for Docker group changes to take effect"
echo "  3. Run 'nvim' to start Neovim and let LazyVim install plugins"
echo "  4. Check the sample TypeScript project in ~/projects/typescript-starter"
echo ""
print_status "🎯 NVM Commands:"
echo "  • nvm list - Show installed Node.js versions"
echo "  • nvm install <version> - Install specific Node.js version"
echo "  • nvm use <version> - Switch to specific Node.js version"
echo "  • nvm current - Show current Node.js version"
echo ""
print_status "📁 Project Features:"
echo "  • .nvmrc file for automatic version switching"
echo "  • TypeScript with strict configuration"
echo "  • ESLint and Prettier configured"
echo "  • Development and production scripts ready"
echo ""
print_status "Useful aliases configured:"
echo "  • vim/vi → nvim"
echo "  • ll → exa -la"
echo "  • ls → exa"
echo "  • cat → batcat"
echo "  • find → fd"
echo "  • grep → rg"
echo ""
print_status "TypeScript project commands:"
echo "  • npm run dev - Start development server"
echo "  • npm run build - Build the project"
echo "  • npm run lint - Lint the code"
echo "  • npm run format - Format the code"
echo ""
print_status "Happy coding! 🚀"
