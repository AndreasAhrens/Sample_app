require "spec_helper"

module CC::Analyzer
  describe Engine do
    before do
      FileUtils.mkdir_p("/tmp/cc")
    end

    describe "#run" do
      it "passes the correct options to Container" do
        container = double
        allow(container).to receive(:on_output).and_yield("")
        allow(container).to receive(:run)

        expect(Container).to receive(:new) do |args|
          expect(args[:image]).to eq "codeclimate/foo"
          expect(args[:command]).to eq "bar"
          expect(args[:name]).to match(/^cc-engines-foo/)
        end.and_return(container)

        metadata = { "image" => "codeclimate/foo", "command" => "bar" }
        engine = Engine.new("foo", metadata, "", {}, "")
        engine.run(StringIO.new, ContainerListener.new)
      end

      it "runs a Container in a constrained environment" do
        container = double
        allow(container).to receive(:on_output).and_yield("")

        expect(container).to receive(:run).with(including(
          "--cap-drop", "all",
          "--label", "com.codeclimate.label=a-label",
          "--memory", "512000000",
          "--memory-swap", "-1",
          "--net", "none",
          "--rm",
          "--volume", "/code:/code:ro",
          "--user", "9000:9000",
        ))

        expect(Container).to receive(:new).and_return(container)
        engine = Engine.new("", {}, "/code", {}, "a-label")
        engine.run(StringIO.new, ContainerListener.new)
      end

      it "passes a composite container listener wrapping the given one" do
        container = double
        allow(container).to receive(:on_output).and_yield("")
        allow(container).to receive(:run)

        given_listener = double
        container_listener = double
        expect(CompositeContainerListener).to receive(:new).
          with(
            given_listener,
            kind_of(LoggingContainerListener),
            kind_of(StatsdContainerListener),
            kind_of(RaisingContainerListener),
          ).
          and_return(container_listener)
        expect(Container).to receive(:new).
          with(including(listener: container_listener)).and_return(container)

        engine = Engine.new("", {}, "", {}, "")
        engine.run(StringIO.new, given_listener)
      end

      it "parses stdout for null-delimited issues" do
        container = TestContainer.new([
          "{}",
          "{}",
          "{}",
        ])
        expect(Container).to receive(:new).and_return(container)

        stdout = StringIO.new
        engine = Engine.new("", {}, "", {}, "")
        engine.run(stdout, ContainerListener.new)

        expect(stdout.string).to eq "{\"fingerprint\":\"b99834bc19bbad24580b3adfa04fb947\"}{\"fingerprint\":\"b99834bc19bbad24580b3adfa04fb947\"}{\"fingerprint\":\"b99834bc19bbad24580b3adfa04fb947\"}"
      end

      it "supports issue filtering by check name" do
        container = TestContainer.new([
          %{{"type":"issue","check_name":"foo"}},
          %{{"type":"issue","check_name":"bar"}},
          %{{"type":"issue","check_name":"baz"}},
        ])
        expect(Container).to receive(:new).and_return(container)

        stdout = StringIO.new
        config = { "checks" => { "bar" => { "enabled" => false } } }
        engine = Engine.new("", {}, "", config, "")
        engine.run(stdout, ContainerListener.new)

        expect(stdout.string).not_to include %{"check":"bar"}
      end
    end
  end
end
