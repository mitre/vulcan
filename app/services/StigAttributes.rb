#!/usr/local/bin/ruby
# encoding: utf-8
# author: Aaron Lippold
# author: Rony Xavier rx294@nyu.edu

require 'happymapper'
require 'nokogiri'

module Services
  class Check
    include HappyMapper
    tag 'check'
    
    element 'check-content', String, tag: 'check-content'
  end

  class Fix
    include HappyMapper
    tag 'fix'
    
    attribute :id, String, tag: 'id'
  end

  class Rule
    include HappyMapper
    tag 'Rule'
    
    attribute :id, String, tag: 'id'
    attribute :severity, String, tag: 'severity'
    element :version, String, tag: 'version'
    element :title, String, tag: 'title'
    element :description, String, tag: 'description'
    has_many :idents, String, tag: 'ident'
    element :fixtext, String, tag: 'fixtext'
    has_one :fix, Fix, tag: 'fix'
    has_one :check, Check, tag: 'check'
  end

  class Group
    include HappyMapper
    tag 'Group'
    
    attribute :id, String, tag: 'id'
    element :title, String, tag: 'title'
    element :description, String, tag: 'description'
    has_one :rule, Rule, tag: 'Rule'
  end

  class ReferenceInfo
    include HappyMapper
    tag 'reference'
    
    attribute :href, String, :tag => 'href'
    element :publisher, String, :tag => 'publisher', :namespace => 'dc'
    element :source, String, :tag => 'source', :namespace => 'dc'
  end

  class ReleaseDate
    include HappyMapper
    tag 'status'
    
    attribute :release_date, String, tag: 'date'
  end

  class Benchmark
    include HappyMapper
    tag 'Benchmark'
    
    has_one :release_date, ReleaseDate, tag: 'status'
    element :status, String, tag: 'status'
    element :title, String, tag: 'title'
    element :description, String, tag: 'description'
    element :version, String, tag: 'version'
    has_one :reference, ReferenceInfo, tag: 'reference'
    has_many :group, Group, tag: 'Group'
  end
end