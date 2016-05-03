{
  title: 'Device Magic',

  # HTTP basic auth example.
  connection: {
    fields: [
      {
        name: 'org_id',
        hint: 'Your organization id'
      },
      {
        name: 'apikey',
        optional: false,
        hint: 'Your API key'
      }
    ],

    authorization: {
      type: 'basic_auth',

      # Basic auth credentials are just the username(API Key) and 'x' as password;
      credentials: ->(connection) {
          user(connection['apikey'])
          password('x')
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
      fields: ->() {
        [
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
    
    allsubmissions: {
   		fields: ->() {
        [
          {
            name: 'per_page'
          },
          {
            name: 'current_page', type: :integer
          },
          {
            name: 'total_pages', type: :integer
          },
          {
            name: 'current_count', type: :integer
          },
    			{
            name: 'total_count', type: :integer
          },
          {
            name: 'submissions', type: :array, of: :object, properties: :object_definitions['submission']
          }    
        ]
      }
  	},
    
    submission: {
      fields: ->() {
        [
        	{
            name:'formname'
          },
          {
            name: 'user'
          },
          {
            name: 'submitted_at', type: :datetime
          },
          {
            name: 'submission_id', type: :integer
          },
          {
            name: 'submission_data'
          }
        ]
      }
    }
    
    },

  test: ->(connection) {
    get("https://devicemagic.com/organizations/#{connection['org_id']}/workato/test_connection.json")
  },

  actions: {
    
    list_forms: {
      input_fields: ->(object_definitions) {
        [
          {
            name: 'org_id', type: :integer, optional: false
          }
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
          {
            name: 'org_id', type: :integer, optional: false
          },
          {
            name: 'form_id',type: :integer, optional: false 
          }
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
        [
          {
            name: 'form_id', type: :integer, optional: false
          },
          { 
            name: 'from_date', type: :date, optional: true 
          },
          { 
            name: 'to_date', type: :date, optional: true 
          },
          { 
            name: 'submission_ids',optional: true 
          },
          { 
            name: 'device_ids',optional: true 
          },
          { 
            name: 'search',optional: true 
          }
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
        [
          {
            name: 'submissions',
            type: :array,
            of: :object,
            properties: object_definitions['allsubmissions']
          } 
        ]
      }   
    },
    
    get_a_submission: {
      input_fields: ->(object_definitions) {
        [
          {
            name: 'form_id', type: :integer, optional: false
          },
          { 
            name: 'submission_id',optional: false 
          }
        ]
      },
      
      execute: ->(connection, input) {
        {
          'submission':get("https://devicemagic.com/api/forms/#{input['form_id']}/workato").
            params(submission_ids: input['submission_id'])['submissions'][0]
        }
      },
      
      output_fields: ->(object_definitions) { 
        [
          {
            name: 'submission',
            type: :object,
            properties: object_definitions['allsubmissions']
          }
      	]
      }  
    }
    
  },

  triggers: {
    
    new_submission: {

      input_fields: ->() {
        [
          {
            name: 'form_id', 
            type: :integer, 
            optional: false
          },
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
  
        {
          events: submissions['submissions'],
          next_poll: next_updated_since,
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
