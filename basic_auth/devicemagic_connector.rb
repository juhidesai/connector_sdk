{
  title: 'Device Magic',

  # HTTP basic auth example.
  connection: {
    fields: [
      {
        name: 'baseurl',
        hint: 'Your org URL'
      },
      {
        name: 'username',
        optional: true,
        hint: 'Your username; leave empty if using API key below'
      },
      {
        name: 'password',
        control_type: 'password',
        label: 'Password or personal API key'
      }
    ],

    authorization: {
      type: 'basic_auth',

      # Basic auth credentials are just the username and password; framework handles adding
      # them to the HTTP requests.
      credentials: ->(connection) {
        # Freshdesk-specific quirk: If only using API key to authenticate, API expects it as username,
        # but we prefer to store it in 'password' to keep it obscured (control_type: 'password' above).
        if connection['username'].blank?
          user(connection['password'])
        else
          user(connection['username'])
          password(connection['password'])
        end
      }
    }
  },

  object_definitions: {

    allforms: {

      fields: ->() {
        [
          {
            name: 'id',
            type: :integer
          },
          {
            name: 'name'
          },
          {
            name: 'namespace'
          },
          {
            name: 'version'
          },
          {
            name: 'description'
          },
          {
            name: 'group'
          }
          

        ]
      }
      
    },
    
    form: {
      fields: ->(){
        [
        #[object_descriptions[]]
        	{
            name: 'title'
          },
          {
            name: 'description'
          },
          {
            name: 'children'
          }
          ]
        }
      
      },
    
    myform: {
      fields: ->(){
        [
        	{
            name: 'val'
          }
          ]
        }
      
      },
    
    allsubmissions: {
   	fields: ->() {
          [
          {name: 'per_page'},
            {name: 'current_page', type: :integer},
            {name: 'total_pages', type: :integer},
            {name: 'current_count', type: :integer},
    {name: 'total_count', type: :integer},
            {name: 'submissions'}
            
          ]
      }
  },
    
    submission: {
      fields: ->() {
        [
        	{name:'formname'},
          {name: 'user'},
          {name: 'submitted_at', type: :datetime},
          {name: 'submission_id', type: :integer},
          {name: 'submission_data'}
        ]
        }
      }
    
    },

  test: ->(connection) {
    get("https://devicemagic.com/api/forms/5290788/device_magic_database.json")
  },

  actions: {
    
    list_forms: {
      input_fields: ->(object_definitions) {
        # Assuming here that the API only allows searching by these terms.
        [
          {name: 'org_id', type: :integer, optional: false}
        ]
      },

      execute: ->(connection, input) {
        {
          'forms':get("https://www.devicemagic.com/organizations/#{input['org_id']}/forms.json", input)['forms']
        }
      },

      output_fields: ->(object_definitions) { 
        [
          {
            name: 'forms',
            type: :array,
            of: :object,
            properties: object_definitions['allforms']
          }
      ]
        }
    } ,
    
    get_a_form: {
      
      input_fields: ->(object_definitions) {
        [
          {name: 'org_id', type: :integer, optional: false},
          { name: 'form_id',type: :integer, optional: false }
        ]
      },
      
      execute: ->(connection, input) {
        {
          'form':get("https://www.devicemagic.com/organizations/#{input['org_id']}/forms/#{input['form_id']}.json").to_s
        }
      },
      
      output_fields: ->(object_definitions) { 
        [
          {
            name: 'form'
          }
      ]
        
        }
      
      },
    
    list_submissions: {
      input_fields: ->(object_definitions) {
        # Assuming here that the API only allows searching by these terms.
        [
          {name: 'form_id', type: :integer, optional: false},
          { name: 'from_date', type: :date, optional: true },
          { name: 'to_date', type: :date, optional: true },
          { name: 'submission_ids',optional: true },
          { name: 'device_ids',optional: true },
          { name: 'search',optional: true }
        ]
      },

      execute: ->(connection, input) {
        {
          'submissions':get("https://devicemagic.com/api/forms/#{input['form_id']}/workato").
            params(from_date: input['from_date'],
                        to_date: input['to_date'],
                             submission_ids: input['submissions_id'],
                             device_ids: input['device_ids'],
                             search: input['search'])
        }
      },

      output_fields: ->(object_definitions) {
#             object_definitions['submissions']
           [ name: 'submissions',
            type: :object,
properties: object_definitions['allsubmissions']  ]
          }
      
    },
    
    get_a_submission: {
      input_fields: ->(object_definitions) {
        [
          {name: 'form_id', type: :integer, optional: false},
          { name: 'submission_id',optional: false }
        ]
      },
      
      execute: ->(connection, input) {
        {
          'submission':get("https://devicemagic.com/api/forms/#{input['form_id']}/workato").
            params(submission_ids: input['submission_id'])['submissions'][0].to_s
        }
      },
      
      output_fields: ->(object_definitions) { [
          {
            name: 'submission'
          }
      ]}
      
      }
    
  },

  triggers: {
    
    new_submission: {

      input_fields: ->() {
        [
          {name: 'form_id', type: :integer, optional: false},
          {
            name: 'since',
            type: :timestamp,
            hint: 'Defaults to tickets created after the recipe is first started'
          }
        ]
      },

      poll: ->(connection, input, last_updated_since) {
        updated_since = last_updated_since || input['since']
        submissions = get("https://devicemagic.com/api/forms/#{input['form_id']}/workato").
            params(from_date: updated_since)

        next_updated_since = submissions['submissions'][0]['submitted_at'] unless submissions['submissions'].blank?
        # Return three items:
        # - The polled objects/events (default: empty/nil if nothing found)
        # - Any data needed for the next poll (default: nil, uses one from previous poll if available)
        # - Flag on whether more objects/events may be immediately available (default: false)
        {
          events: submissions['submissions'],
          next_poll: next_updated_since,
          # common heuristic when no explicit next_page available in response: full page means maybe more.
          can_poll_more: submissions['submissions'].length >= 2
        }
      },

      dedup: ->(submission) {

        submission['submission_id']
      },

      output_fields: ->(object_definitions) {
          object_definitions['submission']
      }
    }
    

  }
}
