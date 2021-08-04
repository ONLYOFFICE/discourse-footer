import Component from "@ember/component";
import { inject as service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
    userService: service("user-service"),

    @discourseComputed("userService.users")
    count() {
    }
});