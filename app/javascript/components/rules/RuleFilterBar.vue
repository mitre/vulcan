<template>
  <div class="filter-bar bg-light px-3 py-2">
    <!-- Header row -->
    <div class="d-flex align-items-center mb-2">
      <strong class="mr-2">Show</strong>
      <span class="text-primary clickable" @click="resetFilters">reset</span>
    </div>

    <!-- Row 1: Control Status -->
    <div class="filter-row d-flex align-items-center mb-2">
      <span class="row-label">Status:</span>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.acFilterChecked"
          switch
          size="sm"
          @change="toggleFilter('acFilterChecked')"
        >
          Applicable - Configurable
        </b-form-checkbox>
        <span class="count">({{ counts.ac }})</span>
      </div>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.aimFilterChecked"
          switch
          size="sm"
          @change="toggleFilter('aimFilterChecked')"
        >
          Applicable - Inherently Meets
        </b-form-checkbox>
        <span class="count">({{ counts.aim }})</span>
      </div>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.adnmFilterChecked"
          switch
          size="sm"
          @change="toggleFilter('adnmFilterChecked')"
        >
          Applicable - Does Not Meet
        </b-form-checkbox>
        <span class="count">({{ counts.adnm }})</span>
      </div>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.naFilterChecked"
          switch
          size="sm"
          @change="toggleFilter('naFilterChecked')"
        >
          Not Applicable
        </b-form-checkbox>
        <span class="count">({{ counts.na }})</span>
      </div>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.nydFilterChecked"
          switch
          size="sm"
          @change="toggleFilter('nydFilterChecked')"
        >
          Not Yet Determined
        </b-form-checkbox>
        <span class="count">({{ counts.nyd }})</span>
      </div>
    </div>

    <!-- Row 2: Review Status -->
    <div class="filter-row d-flex align-items-center mb-2">
      <span class="row-label">Review:</span>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.nurFilterChecked"
          switch
          size="sm"
          @change="toggleFilter('nurFilterChecked')"
        >
          Not Under Review
        </b-form-checkbox>
        <span class="count">({{ counts.nur }})</span>
      </div>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.urFilterChecked"
          switch
          size="sm"
          @change="toggleFilter('urFilterChecked')"
        >
          Under Review
        </b-form-checkbox>
        <span class="count">({{ counts.ur }})</span>
      </div>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.lckFilterChecked"
          switch
          size="sm"
          @change="toggleFilter('lckFilterChecked')"
        >
          Locked
        </b-form-checkbox>
        <span class="count">({{ counts.lck }})</span>
      </div>
    </div>

    <!-- Row 3: Display Options -->
    <div class="filter-row d-flex align-items-center">
      <span class="row-label">Display:</span>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.nestSatisfiedRulesChecked"
          switch
          size="sm"
          @change="toggleFilter('nestSatisfiedRulesChecked')"
        >
          Nest Satisfied
        </b-form-checkbox>
      </div>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.showSRGIdChecked"
          switch
          size="sm"
          @change="toggleFilter('showSRGIdChecked')"
        >
          SRG ID
        </b-form-checkbox>
      </div>
      <div class="filter-group">
        <b-form-checkbox
          :checked="filters.sortBySRGIdChecked"
          switch
          size="sm"
          @change="toggleFilter('sortBySRGIdChecked')"
        >
          Sort SRG
        </b-form-checkbox>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "RuleFilterBar",
  props: {
    filters: {
      type: Object,
      required: true,
    },
    counts: {
      type: Object,
      required: true,
    },
  },
  methods: {
    toggleFilter(filterName) {
      this.$emit("update:filter", filterName, !this.filters[filterName]);
    },
    resetFilters() {
      this.$emit("reset");
    },
  },
};
</script>

<style scoped>
.filter-bar {
  font-size: 0.8125rem;
  border-radius: 0.375rem;
  border: 1px solid #dee2e6;
  margin-bottom: 1.5rem;
}

.filter-row {
  flex-wrap: wrap;
  gap: 0.25rem 0;
}

.row-label {
  font-weight: 600;
  min-width: 60px;
  margin-right: 0.75rem;
  color: #495057;
}

.filter-group {
  display: flex;
  align-items: center;
  margin-right: 1.25rem;
  white-space: nowrap;
}

.count {
  font-size: 0.75rem;
  color: #6c757d;
  margin-left: 0.125rem;
}

/* Tighten switch styling */
.filter-group >>> .custom-control-label {
  font-size: 0.8125rem;
  padding-top: 0.125rem;
}

.filter-group >>> .custom-switch {
  padding-left: 2.25rem;
}

/* Responsive: Small screens (< 768px) */
@media (max-width: 767.98px) {
  .filter-bar {
    padding: 0.75rem !important;
  }

  .filter-row {
    flex-direction: column;
    align-items: flex-start !important;
    gap: 0.5rem;
  }

  .row-label {
    min-width: auto;
    width: 100%;
    margin-bottom: 0.25rem;
    margin-right: 0;
  }

  .filter-group {
    margin-right: 0;
    margin-bottom: 0.25rem;
    padding-left: 0.5rem;
  }
}

/* Responsive: Medium screens (768px - 991px) */
@media (min-width: 768px) and (max-width: 991.98px) {
  .filter-group {
    margin-right: 0.75rem;
  }

  .filter-group >>> .custom-control-label {
    font-size: 0.75rem;
  }
}
</style>
