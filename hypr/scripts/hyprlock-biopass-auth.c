#define _GNU_SOURCE
#include <security/pam_appl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int conv_cb(int num_msg, const struct pam_message **msg,
                   struct pam_response **resp, void *appdata) {
    (void)msg;
    (void)appdata;
    if (num_msg <= 0)
        return PAM_CONV_ERR;
    *resp = calloc((size_t)num_msg, sizeof(struct pam_response));
    if (!*resp)
        return PAM_BUF_ERR;
    for (int i = 0; i < num_msg; i++) {
        (*resp)[i].resp = strdup("");
        (*resp)[i].resp_retcode = 0;
    }
    return PAM_SUCCESS;
}

int main(int argc, char **argv) {
    const char *user = argc > 1 ? argv[1] : getenv("USER");
    const char *service = argc > 2 ? argv[2] : "hyprlock-biopass";
    if (!user || !user[0])
        return 1;

    pam_handle_t *pamh = NULL;
    struct pam_conv conv = {conv_cb, NULL};
    int rc = pam_start(service, user, &conv, &pamh);
    if (rc != PAM_SUCCESS)
        return 1;

    rc = pam_authenticate(pamh, 0);
    pam_end(pamh, rc);
    return rc == PAM_SUCCESS ? 0 : 1;
}
