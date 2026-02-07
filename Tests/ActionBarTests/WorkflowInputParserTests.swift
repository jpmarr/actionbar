import Testing
@testable import ActionBar

@Suite("WorkflowInputParser")
struct WorkflowInputParserTests {

    @Test("Parses simple string input")
    func simpleStringInput() {
        let yaml = """
        on:
          workflow_dispatch:
            inputs:
              name:
                description: 'Name to greet'
                required: true
                type: string
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 1)
        #expect(inputs[0].name == "name")
        #expect(inputs[0].description == "Name to greet")
        #expect(inputs[0].required == true)
        #expect(inputs[0].type == .string)
    }

    @Test("Parses boolean input")
    func booleanInput() {
        let yaml = """
        on:
          workflow_dispatch:
            inputs:
              dry_run:
                description: 'Run without making changes'
                required: false
                type: boolean
                default: 'false'
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 1)
        #expect(inputs[0].name == "dry_run")
        #expect(inputs[0].type == .boolean)
        #expect(inputs[0].required == false)
        #expect(inputs[0].defaultValue == "false")
    }

    @Test("Parses choice input with options")
    func choiceInput() {
        let yaml = """
        on:
          workflow_dispatch:
            inputs:
              environment:
                description: 'Target environment'
                required: true
                type: choice
                options:
                  - staging
                  - production
                  - development
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 1)
        #expect(inputs[0].name == "environment")
        #expect(inputs[0].type == .choice)
        #expect(inputs[0].options == ["staging", "production", "development"])
    }

    @Test("Parses number input")
    func numberInput() {
        let yaml = """
        on:
          workflow_dispatch:
            inputs:
              count:
                description: 'Number of iterations'
                type: number
                default: '5'
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 1)
        #expect(inputs[0].type == .number)
        #expect(inputs[0].defaultValue == "5")
    }

    @Test("Parses multiple inputs")
    func multipleInputs() {
        let yaml = """
        on:
          workflow_dispatch:
            inputs:
              name:
                description: 'Name'
                type: string
              verbose:
                description: 'Verbose output'
                type: boolean
              env:
                description: 'Environment'
                type: choice
                options:
                  - dev
                  - prod
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 3)
        #expect(inputs[0].name == "name")
        #expect(inputs[1].name == "verbose")
        #expect(inputs[2].name == "env")
        #expect(inputs[2].options == ["dev", "prod"])
    }

    @Test("Returns empty for no workflow_dispatch trigger")
    func noDispatchTrigger() {
        let yaml = """
        on:
          push:
            branches: [main]
          pull_request:
            branches: [main]
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.isEmpty)
    }

    @Test("Returns empty for workflow_dispatch without inputs")
    func dispatchWithoutInputs() {
        let yaml = """
        on:
          workflow_dispatch:

        jobs:
          build:
            runs-on: ubuntu-latest
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.isEmpty)
    }

    @Test("Handles comments in YAML")
    func commentsInYaml() {
        let yaml = """
        on:
          workflow_dispatch:
            inputs:
              # This is a comment
              branch:
                description: 'Branch to deploy'
                # Another comment
                required: true
                type: string
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 1)
        #expect(inputs[0].name == "branch")
        #expect(inputs[0].required == true)
    }

    @Test("Handles default values with quotes")
    func defaultValues() {
        let yaml = """
        on:
          workflow_dispatch:
            inputs:
              message:
                description: "A greeting message"
                type: string
                default: "Hello World"
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 1)
        #expect(inputs[0].defaultValue == "Hello World")
        #expect(inputs[0].description == "A greeting message")
    }

    @Test("Parses environment type input")
    func environmentTypeInput() {
        let yaml = """
        on:
          workflow_dispatch:
            inputs:
              target:
                description: 'Deployment target'
                type: environment
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 1)
        #expect(inputs[0].type == .environment)
    }

    @Test("Handles workflow with multiple triggers including dispatch")
    func multipleTriggersWithDispatch() {
        let yaml = """
        on:
          push:
            branches: [main]
          workflow_dispatch:
            inputs:
              tag:
                description: 'Release tag'
                required: true
                type: string
          pull_request:
            branches: [main]
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 1)
        #expect(inputs[0].name == "tag")
    }

    @Test("Input without explicit type defaults to string")
    func defaultsToString() {
        let yaml = """
        on:
          workflow_dispatch:
            inputs:
              message:
                description: 'A message'
                required: false
        """
        let inputs = WorkflowInputParser.parseInputs(from: yaml)
        #expect(inputs.count == 1)
        #expect(inputs[0].type == .string)
    }
}
