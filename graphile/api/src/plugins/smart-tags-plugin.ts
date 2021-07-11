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
                    user_email_key: {
                        tags: {
                            omit: true,
                        },
                    },
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
        procedure: {},
    },
})
