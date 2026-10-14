require_relative 'editor'

module Lightbend
  module Application
    module_function

    def run
      unless java.lang.System.get_property('java.version').start_with?('25.')
        abort 'Lightbend Studio requires JDK 25. Set JAVA_HOME to your JDK 25 installation.'
      end
      closed = java.util.concurrent.CountDownLatch.new(1)
      javax.swing.SwingUtilities.invoke_and_wait do
        editor = Editor.new
        editor.frame.add_window_listener(Lifetime.new(closed))
        editor.show
      end
      closed.await
    end

    class Lifetime < java.awt.event.WindowAdapter
      def initialize(closed)
        super()
        @closed = closed
      end

      def windowClosed(_event) = @closed.count_down
    end
  end
end
