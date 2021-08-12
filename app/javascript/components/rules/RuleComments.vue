<template>
  <div>
    <h2>Comments</h2>

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
        ></b-form-textarea>
      </b-form-group>
      <b-button type="submit" variant="primary">Comment</b-button>
    </b-form>
  </div>
</template>

<script>
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
    }
  },
  methods: {
    commentFormSubmitted(event) {
      event.preventDefault();
      alert("Would have POST to create comment: " + JSON.stringify(this.newCommentBody));
      this.newCommentBody = "";
    },
    friendlyDateTime(dateTimeString) {
      const date = new Date(dateTimeString);
      const hours = date.getHours();
      const amOrPm = hours < 12 ? ' AM' : ' PM';
      const minutes = date.getMinutes() < 10 ? "0" + date.getMinutes() : date.getMinutes()
      const timeString = (hours > 12 ? hours - 12 : hours) + ":" + minutes + amOrPm;
      return date.toDateString() + " @ " + timeString;
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
</style>
