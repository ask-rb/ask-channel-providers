# frozen_string_literal: true

require_relative "test_helper"

class CardTest < Minitest::Test
  def test_builds_card_with_sections
    card = Ask::ChannelProviders::Card.new do |c|
      c.section "Status"
      c.text "All systems go"
    end

    assert_equal 1, card.sections.length
    assert_equal "Status", card.sections[0].title
    assert_equal 1, card.sections[0].components.length
    assert_kind_of Ask::ChannelProviders::Card::TextBlock, card.sections[0].components[0]
  end

  def test_builds_card_with_buttons
    card = Ask::ChannelProviders::Card.new do |c|
      c.section "Actions"
      c.button "Approve", callback: "approve:123"
      c.button "Deny", callback: "deny:123"
    end

    assert_equal 2, card.sections[0].components.length
    btn1 = card.sections[0].components[0]
    assert_kind_of Ask::ChannelProviders::Card::Button, btn1
    assert_equal "Approve", btn1.label
    assert_equal "approve:123", btn1.callback
  end

  def test_builds_card_with_table
    card = Ask::ChannelProviders::Card.new do |c|
      c.section "Results"
      c.table header: ["Name", "Status"], rows: [["test.rb", "✅"], ["lib.rb", "✅"]]
    end

    table = card.sections[0].components[0]
    assert_kind_of Ask::ChannelProviders::Card::Table, table
    assert_equal ["Name", "Status"], table.header
    assert_equal 2, table.rows.length
  end

  def test_builds_card_with_button_url
    card = Ask::ChannelProviders::Card.new do |c|
      c.button "Open", url: "https://example.com"
    end
    btn = card.sections[0].components[0]
    assert_equal "https://example.com", btn.url
    assert_nil btn.callback
  end

  def test_render_card_to_text
    card = Ask::ChannelProviders::Card.new do |c|
      c.section "Deploy"
      c.text "Build passed"
      c.table header: ["File", "Status"], rows: [["app.rb", "✅"]]
    end

    text = Ask::ChannelProviders::Adapter.new.render_card_to_text(card)
    assert_includes text, "Deploy"
    assert_includes text, "Build passed"
    assert_includes text, "File"
    assert_includes text, "✅"
  end

  def test_render_empty_card
    card = Ask::ChannelProviders::Card.new
    text = Ask::ChannelProviders::Adapter.new.render_card_to_text(card)
    assert text.empty?
  end

  def test_render_card_with_divider
    card = Ask::ChannelProviders::Card.new do |c|
      c.section "Top"
      c.text "Above"
      c.divider
      c.text "Below"
    end

    text = Ask::ChannelProviders::Adapter.new.render_card_to_text(card)
    assert_includes text, "Above"
    assert_includes text, "Below"
  end
end
