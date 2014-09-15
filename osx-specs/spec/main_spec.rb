
describe "Application 'my-motion-osx-2'" do
  before do
    @app = NSApplication.sharedApplication
  end

  it "has one window" do
    @app.windows.size.should == 1
  end

  # motion-kit kvo

  # it "should observe" do
  #   class KVOObserver
  #     # include ::KVOMixin
  #     include ::Reactive

  #     attr_accessor :prop
  #   end

  #   a = KVOObserver.new

  #   a.react_to :prop do
  #   end
  # end

  # find carousel

  before {
    @c = Carousel.new({
        a: -> {

        },
        b: -> {

        }  
      },
      :a
    )
  }

  it "inits with initial state" do
    @c.current_state .should == :a
  end

  it "switches to next state when asked" do
    @c.next
    @c.current_state .should == :b
  end

  it "can be kept synchronised using kvo" do
    class Observee
      attr_accessor :prop
    end

    obj1 = Observee.new

    @c.sync_state obj1, :prop do |val|
      p "new val: #{val}"
      case val
      when :to_a
        :a
      when :to_b
        :b
      else
        raise "unhandle val #{val}"
      end
    end

    obj1.prop = :to_b
    @c.current_state .should == :b
  end

end
