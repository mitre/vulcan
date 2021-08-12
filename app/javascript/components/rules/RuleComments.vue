<template>
  <div>
    <div @click="showComments = !showComments">
      <h2 class="commentsHeading">Comments</h2>
      <b-badge pill class="superVerticalAlign">{{rule.comments.length}}</b-badge>

      <i class="mdi mdi-menu-down superVerticalAlign collapsableArrow" v-if="showComments"></i>
      <i class="mdi mdi-menu-up superVerticalAlign collapsableArrow" v-if="!showComments"></i>
    </div>

    <b-collapse id="collapse-comments" v-model="showComments">
      <!-- All comments -->
      <div :key="comment.id" v-for="comment in rule.comments">
        <p class="commentHeader"><strong>{{comment.name}}</strong></p>
        <p class="commentTimestamp"><small>{{friendlyDateTime(comment.created_at)}}</small></p>
        <p class="commentBody">{{comment.body}}</p>
      </div>

      <!-- Create a new comment -->
      <b-form class="newCommentForm" @submit="commentFormSubmitted">
        <b-form-group>
          <b-form-textarea
            v-model="newCommentBody"
            name="comment[body]"
            placeholder="Enter a comment..."
            rows="3"
            required
          ></b-form-textarea>
        </b-form-group>
        <b-button type="submit" variant="primary">Comment</b-button>
      </b-form>
    </b-collapse>
  </div>
</template>

<script>
import axios from 'axios';
export default {
  name: 'ControlComments',
  props: {
    rule: {
      type: Object,
      required: true,
    }
  },
  data: function() {
    return {
      newCommentBody: "",
      showComments: false
    }
  },
  computed: {
    // Authenticity Token for forms
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
  },
  methods: {
    commentFormSubmitted: function(event) {
      event.preventDefault();
      // guard against invalid comment body
      if (! this.newCommentBody.trim()) {
        return;
      }

      axios.defaults.headers.common['X-CSRF-Token'] = this.authenticityToken;
      axios.post(`/rules/${this.rule.id}/comments`, {
        body: this.newCommentBody.trim()
      })
      .then(this.commentPostSuccess)
      .catch(this.commentPostError);
    },
    // Upon success, emit an event to the parent that indicates that this rule should be re-fetched.
    commentPostSuccess: function(response) {
      this.newCommentBody = "";
      this.$emit('ruleUpdated', this.rule.id);
    },
    commentPostError: function(response) {
      alert('failed to comment!')
    },
    friendlyDateTime: function(dateTimeString) {
      const date = new Date(dateTimeString);
      const hours = date.getHours();
      const amOrPm = hours < 12 ? ' AM' : ' PM';
      const minutes = date.getMinutes() < 10 ? "0" + date.getMinutes() : date.getMinutes()
      const timeString = (hours > 12 ? hours - 12 : hours) + ":" + minutes + amOrPm;
      return `${date.toDateString()} @ ${timeString}`;
    }
  }
}
</script>

<style scoped>
.commentHeader {
  margin: 1em 0em 0em 1em;
}

.commentTimestamp {
  margin: 0em 0em 0em 1em;
}

.commentBody {
  margin: 0em 0em 0em 2em;
}

.newCommentForm {
  margin: 1em 0em 0em 1em;
}

.superVerticalAlign {
  vertical-align: super;
}

.commentsHeading {
  display: inline-block;
  margin: 0;
}

.collapsableArrow {
  font-size: 1.5em;
}
</style>
