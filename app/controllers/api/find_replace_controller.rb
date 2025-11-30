# frozen_string_literal: true

module Api
  ##
  # API controller for find and replace operations within components
  #
  # All text manipulation happens server-side. Frontend only receives
  # match metadata and calls replace endpoints.
  #
  # Endpoints:
  #   POST /api/components/:component_id/find_replace/find
  #   POST /api/components/:component_id/find_replace/replace_instance
  #   POST /api/components/:component_id/find_replace/replace_field
  #   POST /api/components/:component_id/find_replace/replace_all
  #
  class FindReplaceController < ApplicationController
    before_action :authenticate_user!
    before_action :set_component
    before_action :authorize_read, only: [:find]
    before_action :authorize_write, except: [:find]
    skip_before_action :setup_navigation
    skip_before_action :check_access_request_notifications

    rescue_from ActionController::ParameterMissing do |exception|
      render json: { error: exception.message }, status: :bad_request
    end

    rescue_from ActiveRecord::RecordNotFound do |_exception|
      render json: { error: 'Not found' }, status: :not_found
    end

    rescue_from NotAuthorizedError do |exception|
      render json: { error: exception.message }, status: :unauthorized
    end

    ##
    # Find all matches in component
    #
    # POST /api/components/:component_id/find_replace/find
    #
    # Params:
    #   search: string (required) - text to find
    #   fields: array (optional) - fields to search, default: all
    #   case_sensitive: boolean (optional) - default: false
    #
    # Response:
    #   {
    #     total_matches: 47,
    #     total_rules: 12,
    #     matches: [
    #       {
    #         rule_id: 1,
    #         rule_identifier: "SV-001",
    #         match_count: 3,
    #         instances: [
    #           {
    #             field: "fixtext",
    #             instances: [
    #               { index: 45, length: 4, text: "sshd", context: "...configure sshd to..." }
    #             ]
    #           }
    #         ]
    #       }
    #     ]
    #   }
    #
    def find
      search_text = params.require(:search)

      service = FindReplaceService.new(
        @component,
        search_text,
        fields: params[:fields],
        case_sensitive: case_sensitive?
      )

      render json: service.find
    end

    ##
    # Replace a single instance within a field
    #
    # POST /api/components/:component_id/find_replace/replace_instance
    #
    # Params:
    #   search: string (required) - text that was searched for
    #   rule_id: integer (required) - rule to modify
    #   field: string (required) - field containing the match
    #   instance_index: integer (required) - which occurrence (0-based)
    #   replacement: string (required) - replacement text
    #   audit_comment: string (optional) - audit trail comment
    #   case_sensitive: boolean (optional) - default: false
    #
    # Response:
    #   { success: true, rule: {...} }
    #   { success: false, error: "..." }
    #
    def replace_instance
      service = build_service

      result = service.replace_instance(
        rule_id: params.require(:rule_id).to_i,
        field: params.require(:field),
        instance_index: params.require(:instance_index).to_i,
        replacement: params.require(:replacement),
        audit_comment: params[:audit_comment] || 'Find & Replace'
      )

      if result[:success]
        render json: {
          success: true,
          rule: RuleBlueprint.render_as_hash(result[:rule])
        }
      else
        render json: { success: false, error: result[:error] }, status: :unprocessable_content
      end
    end

    ##
    # Replace all instances within a single field of a rule
    #
    # POST /api/components/:component_id/find_replace/replace_field
    #
    # Params:
    #   search: string (required) - text to find
    #   rule_id: integer (required) - rule to modify
    #   field: string (required) - field to update
    #   replacement: string (required) - replacement text
    #   audit_comment: string (optional) - audit trail comment
    #   case_sensitive: boolean (optional) - default: false
    #
    # Response:
    #   { success: true, rule: {...}, replaced_count: 3 }
    #   { success: false, error: "..." }
    #
    def replace_field
      service = build_service

      result = service.replace_field(
        rule_id: params.require(:rule_id).to_i,
        field: params.require(:field),
        replacement: params.require(:replacement),
        audit_comment: params[:audit_comment] || 'Find & Replace'
      )

      if result[:success]
        render json: {
          success: true,
          rule: RuleBlueprint.render_as_hash(result[:rule]),
          replaced_count: result[:replaced_count]
        }
      else
        render json: { success: false, error: result[:error] }, status: :unprocessable_content
      end
    end

    ##
    # Replace all matches across all rules in the component
    #
    # POST /api/components/:component_id/find_replace/replace_all
    #
    # Params:
    #   search: string (required) - text to find
    #   replacement: string (required) - replacement text
    #   fields: array (optional) - fields to search, default: all
    #   audit_comment: string (optional) - audit trail comment
    #   case_sensitive: boolean (optional) - default: false
    #
    # Response:
    #   { success: true, rules_updated: 12, matches_replaced: 47 }
    #   { success: false, error: "...", rules_updated: 5, matches_replaced: 23 }
    #
    def replace_all
      service = build_service

      result = service.replace_all(
        replacement: params.require(:replacement),
        audit_comment: params[:audit_comment] || 'Find & Replace (all)'
      )

      if result[:success]
        render json: {
          success: true,
          rules_updated: result[:rules_updated],
          matches_replaced: result[:matches_replaced]
        }
      else
        render json: {
          success: false,
          error: result[:error],
          rules_updated: result[:rules_updated] || 0,
          matches_replaced: result[:matches_replaced] || 0
        }, status: :unprocessable_content
      end
    end

    ##
    # Undo the last Find & Replace operation on a rule
    #
    # POST /api/components/:component_id/find_replace/undo
    #
    # Params:
    #   rule_id: integer (required) - the rule to undo changes on
    #
    # Response:
    #   { success: true, rule: {...}, reverted_fields: ["fixtext"] }
    #   { success: false, error: "..." }
    #
    def undo
      # Undo doesn't need a search pattern - create service with empty string
      service = FindReplaceService.new(@component, '')

      result = service.undo(rule_id: params.require(:rule_id).to_i)

      if result[:success]
        render json: {
          success: true,
          rule: RuleBlueprint.render_as_hash(result[:rule]),
          reverted_fields: result[:reverted_fields]
        }
      else
        render json: { success: false, error: result[:error] }, status: :unprocessable_content
      end
    end

    private

    def set_component
      @component = Component.find(params[:component_id])
    end

    def authorize_read
      authorize_viewer_component
    end

    def authorize_write
      authorize_author_component
    end

    def build_service
      FindReplaceService.new(
        @component,
        params.require(:search),
        fields: params[:fields],
        case_sensitive: case_sensitive?
      )
    end

    def case_sensitive?
      params[:case_sensitive].to_s == 'true'
    end
  end
end
