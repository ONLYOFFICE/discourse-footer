import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default Service.extend({
  users: {
    online: 0,
    hidden: 0,
    anonymous: 0
  },

  init() {
    this._super(...arguments);

    ajax("/whosonline/get.json", { method: "GET" })
    .then((result) => {
        if (result.users) {
          this.set("users", result.users);
        }
    }).catch((e) => {
        console.log(e);
    })
  }
});
