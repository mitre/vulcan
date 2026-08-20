# frozen_string_literal: true

Pagy::OPTIONS[:limit]             = 25
Pagy::OPTIONS[:max_limit]         = 100
Pagy::OPTIONS[:page_key]          = 'page'
Pagy::OPTIONS[:limit_key]         = 'per_page'
Pagy::OPTIONS[:raise_range_error] = true
Pagy::OPTIONS.freeze
