module Datadog
  module Contrib
    module RSpec
      # Instrument RSpec::Core::Example
      module Example
        def self.included(base)
          base.send(:prepend, InstanceMethods)
        end

        # Instance methods for configuration
        module InstanceMethods
          def run(example_group_instance, reporter)
            configuration = Datadog.configuration[:rspec]
            return super unless configuration[:enabled]

            trace_options = {
              app: Ext::APP,
              resource: "#{example_group}::#{description}",
              service: configuration[:service_name],
              span_type: Ext::EXAMPLE_SPAN_TYPE
            }

            configuration[:tracer].trace(Ext::EXAMPLE_SPAN_TYPE, trace_options) do |span|
              span.set_tag(Datadog::Ext::Test::TAG_FRAMEWORK, Ext::FRAMEWORK)
              span.set_tag(Datadog::Ext::Test::TAG_NAME, description)
              span.set_tag(Datadog::Ext::Test::TAG_SUITE, example_group)
              span.set_tag(Datadog::Ext::Test::TAG_TYPE, Ext::TEST_TYPE)
              span.set_tag(Datadog::Ext::Test::TAG_SPAN_KIND, Datadog::Ext::AppTypes::TEST)

              # Set analytics sample rate
              if Datadog::Contrib::Analytics.enabled?(configuration[:analytics_enabled])
                Datadog::Contrib::Analytics.set_sample_rate(span, configuration[:analytics_sample_rate])
              end

              # Measure service stats
              Contrib::Analytics.set_measured(span)

              result = super

              case execution_result.status
              when :passed
                span.set_tag(Datadog::Ext::Test::TAG_STATUS, Datadog::Ext::Test::Status::PASS)
              when :failed
                span.status = 1
                span.set_tag(Datadog::Ext::Test::TAG_STATUS, Datadog::Ext::Test::Status::FAIL)
                span.set_error(execution_result.exception)
              else
                if execution_result.example_skipped?
                  span.set_tag(Datadog::Ext::Test::TAG_STATUS, Datadog::Ext::Test::Status::SKIP)
                end
              end
              result
            end
          end
        end
      end
    end
  end
end
