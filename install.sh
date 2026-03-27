#!/bin/bash

# Create '.openserv' folder in home directory
mkdir -p ~/.openserv

# Copy 'src/' folder into '~/.openserv'
cp -r src/. ~/.openserv/

# Print completion message
echo "Installation completed successfully."