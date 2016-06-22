class SimpleCircuitBreaker
  VERSION = '0.3.0'

  class CircuitOpenError < StandardError
    def initialize(message, cause)
      super(message)
      @cause = cause
    end

    attr_reader :cause
  end

  attr_reader :failure_threshold, :retry_timeout

  def initialize(failure_threshold=3, retry_timeout=10)
    @failure_threshold = failure_threshold
    @retry_timeout = retry_timeout
    @last_exception = nil
    reset!
  end

  def handle(*exceptions, &block)
    if tripped?
      raise CircuitOpenError.new('Circuit is open', last_exception)
    else
      execute(exceptions, &block)
    end
  end

protected

  attr_reader :last_exception

  def execute(exceptions, &block)
    result = yield
    reset!
    result
  rescue Exception => e
    if exceptions.empty? || exceptions.any? { |exception| e.class <= exception }
      fail!(e)
    end
    raise
  end

  def fail!(exception)
    @last_exception = exception
    @failures += 1
    if @failures >= @failure_threshold
      @state = :open
      @open_time = Time.now
    end
  end

  def reset!
    @state = :closed
    @failures = 0
  end

  def tripped?
    @state == :open && !timeout_exceeded?
  end

  def timeout_exceeded?
    @open_time + @retry_timeout < Time.now
  end

end
