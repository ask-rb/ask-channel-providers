# frozen_string_literal: true

module Ask
  module ChannelProviders
    # Cross-platform card system for rich message rendering.
    #
    # A Card is a structured UI element that each channel adapter renders
    # into its native format:
    #   Telegram  → Markdown text + inline keyboards
    #   Discord   → Embeds + message components
    #   Slack     → Block Kit
    #
    # @example
    #   card = Ask::ChannelProviders::Card.new do |c|
    #     c.section "Deploy Status"
    #     c.text "Build **#42** passed"
    #     c.button "View Logs", callback: "/logs 42"
    #     c.table header: ["File", "Status"], rows: [["app.rb", "✅"]]
    #   end
    #   @channel.send_card(chat_id, card)
    class Card
      attr_reader :sections

      def initialize
        @sections = []
        yield self if block_given?
      end

      # Add a section title.
      def section(text)
        @sections << Section.new(text)
      end

      # Add a text block to the last section.
      def text(content, style: nil)
        last_section << TextBlock.new(content, style: style)
      end

      # Add a button to the last section.
      def button(label, callback: nil, url: nil)
        last_section << Button.new(label, callback: callback, url: url)
      end

      # Add a table to the last section.
      def table(header:, rows:)
        last_section << Table.new(header, rows)
      end

      # Add a divider line.
      def divider
        last_section << Divider.new
      end

      private

      def last_section
        @sections.last || (@sections << Section.new(""))[-1]
      end

      # ── Components ──────────────────────────────────────────────────────

      Section = Struct.new(:title) do
        attr_reader :components

        def initialize(title)
          super(title)
          @components = []
        end

        def <<(component)
          @components << component
        end
      end

      TextBlock = Struct.new(:content, :style, keyword_init: true)

      Button = Struct.new(:label, :callback, :url, keyword_init: true)

      Table = Struct.new(:header, :rows, keyword_init: true)

      Divider = Struct.new
    end
  end
end
