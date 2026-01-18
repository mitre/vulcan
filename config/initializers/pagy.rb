# frozen_string_literal: true

# Pagy configuration
# See https://ddnexus.github.io/pagy/docs/api/pagy

# Default items per page
Pagy::DEFAULT[:limit] = 50

# Enable overflow handling - return last page when page > last
Pagy::DEFAULT[:overflow] = :last_page
