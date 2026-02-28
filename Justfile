build:
    swift build

clean:
    swift package clean
    rm -rf .build

test:
    swift test

lint:
    @if command -v swiftformat > /dev/null; then \
        swiftformat . --lint; \
    else \
        echo "swiftformat not found, skipping lint"; \
    fi

fmt:
    @if command -v swiftformat > /dev/null; then \
        swiftformat .; \
    else \
        echo "swiftformat not found, skipping fmt"; \
    fi

run:
    swift run richclip
