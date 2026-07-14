#!/bin/bash
# scripts/test.sh

# # Run all tests
# ./scripts/test.sh

# # Run controller specs
# ./scripts/test.sh spec/controllers/

# # Run with coverage
# ./scripts/test.sh -c

# # Run with verbose output
# ./scripts/test.sh -v

# # Run a specific file
# ./scripts/test.sh spec/controllers/users/sessions_controller_spec.rb

# # Run with a specific seed
# ./scripts/test.sh -s 12345

# # Run models with coverage
# ./scripts/test.sh -c spec/models/

# # Run a specific test by line number
# ./scripts/test.sh spec/controllers/users/sessions_controller_spec.rb:45

# # Show help
# ./scripts/test.sh -h

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Check if containers are running
if ! docker-compose -f docker-compose.dev.yaml ps -q api > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  API container is not running. Starting containers...${NC}"
    docker-compose -f docker-compose.dev.yaml up -d
    sleep 5
fi

# ✅ Run tests inside the Docker container
echo -e "${BLUE}🔬 Running tests in Docker...${NC}"
docker-compose -f docker-compose.dev.yaml exec -e RAILS_ENV=test api bundle exec rspec spec/controllers/

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "\n${GREEN}✅ All tests passed!${NC}"
else
    echo -e "\n${RED}❌ Some tests failed.${NC}"
fi

exit $EXIT_CODE
