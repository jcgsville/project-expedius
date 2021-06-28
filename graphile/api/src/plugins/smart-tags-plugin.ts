/* eslint-disable camelcase */
import { makeJSONPgSmartTagsPlugin } from 'graphile-utils'

export const SmartTagsPlugin = makeJSONPgSmartTagsPlugin({
    version: 1,
    config: {
        class: {
            'eg_public.user': {
                tags: {
                    omit: 'all,create,many',
                },
                attribute: {
                    id: {
                        tags: {
                            omit: 'update',
                        },
                    },
                    email: {
                        tags: {
                            omit: 'update',
                        },
                    },
                    user_type: {
                        tags: {
                            omit: 'update',
                        },
                    },
                },
                constraint: {
                    unique_email_id: {
                        tags: {
                            omit: true,
                        },
                    },
                    unique_email: {
                        tags: {
                            omit: true,
                        },
                    },
                },
            },
            'eg_public.user_login_info': {
                tags: {
                    omit: true,
                },
            },
            'eg_public.class': {
                tags: {
                    // TODO: For now, omitting many achieves what I want,
                    // but I suspect this will not be a long term solution
                    // I believe it's not possible to omit a constraint in
                    // one direction, so I may want to create a plugin for
                    // this
                    omit: 'all,many',
                },
                attribute: {
                    // TODO: Get the teacher ID from the JWT
                    id: {
                        tags: {
                            omit: 'create,update',
                        },
                    },
                },
            },
        },
        procedure: {
            'eg_public.save_login_flow': {
                tags: {
                    omit: true,
                },
            },
            'eg_public.retrieve_login_flow': {
                tags: {
                    omit: true,
                },
            },
            'eg_public.srp_creds_by_email': {
                tags: {
                    omit: true,
                },
            },
        },
    },
})
