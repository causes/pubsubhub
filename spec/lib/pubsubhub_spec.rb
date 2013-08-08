require 'spec_helper'

describe PubSubHub do
  let(:listener)     { Object.new }
  let(:registration) { [{ listener: listener }] }

  before do
    @registry = described_class.instance.registry
    PubSubHub.register(some_event: registration)
  end

  after { PubSubHub.register(@registry) if @registery }

  context 'with missing a listener' do
    it 'raises an error' do
      expect do
        PubSubHub.register(some_event: [{ listner_typo: listener }])
      end.to raise_error
    end
  end

  context 'an object subscribed for synchronous notification' do
    it 'runs handler synchronously' do
      listener.expects(:handle_some_event)
      PubSubHub.trigger :some_event
    end
  end

  context 'an object subscribed for asynchronous notification' do
    let(:registration) { [{ listener: listener, async: true }] }

    it 'runs handler via the async dispatcher' do
      PubSubHub.async_dispatcher.expects(:call).with(listener, :handle_some_event, [])
      PubSubHub.trigger :some_event
    end
  end

  context 'a trigger with arguments' do
    let(:args) { [1, 2, 3] }

    it 'runs handler synchronously' do
      listener.expects(:handle_some_event).with(*args)
      PubSubHub.trigger :some_event, *args
    end
  end

  context 'a handler that raises an error' do
    let(:flakey_listener) { Object.new }

    let(:registration) do
      [
        { listener: flakey_listener, handler: :non_existent_method },
        { listener: listener,        handler: :handle_some_event   },
      ]
    end

    it 'does not affect other handlers' do
      listener.expects(:handle_some_event)
      PubSubHub.trigger :some_event
    end
  end

  describe '.async_dispatcher=' do
    let(:args)         { [1, 2, 3] }
    let(:registration) { [{ listener: listener, async: true }] }
    before             { @async_dispatcher = PubSubHub.async_dispatcher }
    after              { PubSubHub.async_dispatcher = @async_dispatcher }

    it 'calls the dispatcher with the listener, handler method and args' do
      dispatcher = mock()
      dispatcher.expects(:call).with(listener, :handle_some_event, args)
      PubSubHub.async_dispatcher = dispatcher
      PubSubHub.trigger :some_event, *args
    end
  end

  describe '.error_handler=' do
    let(:registration) do
      [
        { listener: listener, handler: :exploding_method }
      ]
    end

    before { @error_handler = PubSubHub.error_handler }
    after  { PubSubHub.error_handler = @error_handler }

    it 'calls the error handler with the exception' do
      handler = mock()
      handler.expects(:call).with(instance_of(NoMethodError))
      PubSubHub.error_handler = handler
      PubSubHub.trigger :some_event
    end
  end
end