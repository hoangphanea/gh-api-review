require 'rails_helper'

RSpec.describe FileChange, type: :model do
  it { is_expected.to belong_to :commit }

  describe '.build_random_comments' do
    let(:suggestions_1) do
      {
        '1' => [
          'name' => 'Use have_http_status',
          'matches' => ['404']
        ],
        '3' => [
          'name' => 'Class shorthand',
          'matches' => ['origin' ,'anything', 'abc xyz']
        ]
      }
    end

    let(:suggestions_2) do
      {
        '2' => [
          'name' => 'Missing space',
          'matches' => []
        ]
      }
    end

    let(:expected_result) do
      {
        'Use have_http_status<,>404' => [
          "You may consider using `have_http_status` here for more semantic test",
          "Another way to do that:\n\n```ruby\nexpect(response).to have_http_status :not_found\n```",
          "You could use `expect(response).to have_http_status(:not_found)` instead"
        ],
        'Missing space' => [
          'I think you should put a space here for consistency',
          'Missing a space here',
          'You could put a space here to make it consistent'
        ],
        'Class shorthand<,>origin<,>anything<,>abc xyz' => [
          "Shorthand of this: `origin.abc.xyz`", 
          "It could be shorter: `origin.abc.xyz`"
        ]
      }
    end

    let!(:file_change_1) { create(:file_change, suggestions: suggestions_1) }
    let!(:file_change_2) { create(:file_change, suggestions: suggestions_2) }

    it 'builds random_comments hash' do
      expect(described_class.build_random_comments).to eq expected_result
    end
  end

  describe '#analyze' do
    subject { build(:file_change, line_changes: line_changes, filename: 'sample.rb') }

    let(:line_changes) do
      [
        {
          '+' => {
            line_1 => [value_1],
            line_2 => [value_2],
            line_3 => [value_3]
          }
        },
        {
          '+' => {
            line_4 => [value_4],
            line_5 => [value_5]
          }
        }
      ]
    end

    let(:rules) do
      [
        {
          'regex' => {
            'rb' => '(matching 1)'
          },
          'name' => rule1_name
        },
        {
          'regex' => {
            'all' => 'matching 2'
          },
          'name' => rule2_name
        },
        {
          'regex' => {
            'all' => 'matching 3'
          },
          'name' => rule3_name,
          'offset' => 1
        }
      ]
    end

    let(:expected_result) do
      {
        line_1 => [{
          'name' => rule1_name,
          'matches' => ['matching 1']
        }],
        line_2 => [{
          'name' => rule2_name,
          'matches' => []
        }],
        line_3 => [{
          'name' => rule1_name,
          'matches' => ['matching 1']
        }, {
          'name' => rule2_name,
          'matches' => []
        }],
        (line_5.to_i - 1).to_s => [{
          'name' => rule3_name,
          'matches' => []
        }]
      }
    end

    let(:line_1) { '5' }
    let(:line_2) { '10' }
    let(:line_3) { '11' }
    let(:line_4) { '13' }
    let(:line_5) { '17' }
    let(:value_1) { 'matching 1 and sth' }
    let(:value_2) { 'matching 2' }
    let(:value_3) { 'matching 1 and matching 2' }
    let(:value_4) { 'nomatch' }
    let(:value_5) { 'matching 3' }
    let(:rule1_name) { Faker::Name.name }
    let(:rule2_name) { Faker::Name.name }
    let(:rule3_name) { Faker::Name.name }

    before do
      stub_const('LINE_RULES', rules)
      subject.analyze
    end

    it 'updates suggestions with correct result' do
      expect(subject.suggestions).to eq expected_result
    end
  end

  describe '#match_rules' do
    subject { build(:file_change, filename: "sample.#{extension}") }

    let(:matching) do
      Proc.new do |block|
        subject.send(:match_rules, line, ln, &block)
      end
    end

    let(:extension) { 'html' }
    let(:line) { '' }
    let(:ln) { '3' }

    context 'line is not present' do
      it { expect(matching).not_to yield_control }
    end

    context 'missing new line' do
      let(:line) { '\No newline at end of file' }

      it { expect(matching).to yield_with_args('2', 'New line warning', anything) }
    end

    ['"string_#{ interpolate}"', '"string_#{interpolate }"', '"string_#{  interpolate }"'].each do |value|
      context value do
        let(:line) { value }

        it { expect(matching).to yield_with_args(ln, 'Extra space', anything) }
      end
    end

    context 'missing space for erb' do
      let(:extension) { 'erb' }

      ["<% abc%>", "<%abc %>", "<%=abc%>"].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Missing space', anything) }
        end
      end

      ["<%= abc %>"].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).not_to yield_control }
        end
      end
    end

    context 'missing space for hash' do
      ['{ "bc":123 }', "{ bc:'123' }"].each do |value|
        context value do
          let(:line) { value }

          %w(rb erb haml slim coffee js).each do |lang|
            context lang do
              let(:extension) { lang }

              it { expect(matching).to yield_with_args(ln, 'Missing space', anything) }
            end
          end

          context 'otherwise' do
            let(:extension) { 'xml' }

            it { expect(matching).not_to yield_control }
          end
        end
      end

      [' :abc', 'Faker::Lorem', 'http://'].each do |value|
        let(:extension) { 'rb' }

        context value do
          let(:line) { value }

          it { expect(matching).not_to yield_control }
        end
      end
    end

    context 'missing space after =' do
      let(:line) { 'span.class#id=method(args)' }

      %w(rb erb haml slim coffee js).each do |lang|
        context lang do
          let(:extension) { lang }

          it { expect(matching).to yield_with_args(ln, 'Missing space', anything) }
        end
      end

      context 'otherwise' do
        it { expect(matching).not_to yield_control }
      end
    end

    [' {abc: 123 }', ' { abc: 123}', '{abc => 123}'].each do |value|
      context value do
        let(:line) { value }

        %w(rb erb haml slim coffee js).each do |lang|
          context lang do
            let(:extension) { lang }

            it { expect(matching).to yield_with_args(ln, 'Missing space', anything) }
          end
        end

        context 'otherwise' do
          let(:extension) { 'm' }

          it { expect(matching).not_to yield_control }
        end
      end
    end

    ['{}', ' { }', '+#{value == 1}','{value}', '{ "#{abc}" }'].each do |value|
      context value do
        let(:line) { value }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'starts with return plus' do
      let(:line) { "+  \treturn method" }

      %w(rb coffee).each do |lang|
        context lang do
          let(:extension) { lang }

          it { expect(matching).to yield_with_args(ln, 'Explicit return', anything) }
        end
      end

      context 'otherwise' do
        let(:extension) { 'js' }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'starts with return' do
      let(:line) { 'return method' }

      %w(rb coffee).each do |lang|
        context lang do
          let(:extension) { lang }

          it { expect(matching).to yield_with_args(ln, 'Explicit return', anything) }
        end
      end

      context 'otherwise' do
        let(:extension) { 'js' }

        it { expect(matching).not_to yield_control }
      end
    end

    %w(text email file number hidden).each do |type|
      context "input with type #{type}" do
        context 'erb' do
          let(:extension) { 'erb' }
          let(:line) { "<input type='#{type}'>" }

          it { expect(matching).to yield_with_args(ln, "Use #{type} field tag", anything) }
        end

        context 'haml' do
          let(:extension) { 'haml' }
          let(:line) { "%input{ type: '#{type}' }" }

          it { expect(matching).to yield_with_args(ln, "Use #{type} field tag", anything) }
        end

        context 'slim' do
          let(:extension) { 'slim' }
          let(:line) { "input(type='#{type}')" }

          it { expect(matching).to yield_with_args(ln, "Use #{type} field tag", anything) }
        end

        context 'otherwise' do
          let(:line) { "<input type='#{type}'>" }

          it { expect(matching).not_to yield_control }
        end
      end
    end

    context 'raw select tag' do
      { 'erb' => "<select class='abc'>", 'haml' => '%select.abc', 'slim' => 'select.abc' }.each do |lang, value|
        context lang do
          let(:extension) { lang }
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use select tag', anything) }
        end
      end

      context 'otherwise' do
        let(:line) { "<select class='abc'>" }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'raw img tag' do
      { 'erb' => "<img class='abc'>", 'haml' => '%img.abc', 'slim' => ' img.abc' }.each do |lang, value|
        context lang do
          let(:extension) { lang }
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use image tag', anything) }
        end
      end

      context 'otherwise' do
        let(:line) { "<img class='abc'>" }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'raw a tag' do
      { 'erb' => "<a class='abc'>", 'haml' => '%a.abc', 'slim' => '+ a.abc' }.each do |lang, value|
        context lang do
          let(:extension) { lang }
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use link to', anything) }
        end
      end

      context 'otherwise' do
        let(:line) { "<a class='abc'>" }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'explicit div tag' do
      context 'haml' do
        let(:extension) { 'haml' }
        let(:line) { '%div.abc' }

        it { expect(matching).to yield_with_args(ln, 'Explicit div', anything) }
      end

      context 'slim' do
        let(:extension) { 'slim' }
        let(:line) { 'div.abc' }

        it { expect(matching).to yield_with_args(ln, 'Explicit div', anything) }
      end

      context 'otherwise' do
        let(:extension) { 'erb' }
        let(:line) { "<div class='abc'>" }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'old hash syntax' do
      let(:line) { ':a => 1' }

      %w(rb erb haml slim).each do |lang|
        context lang do
          let(:extension) { lang }

          it { expect(matching).to yield_with_args(ln, 'Old hash syntax', anything) }
        end
      end

      context 'otherwise' do
        it { expect(matching).not_to yield_control }
      end
    end

    context 'filter' do
      let(:line) { 'before_filter :set_args' }

      context 'rb' do
        let(:extension) { 'rb' }

        it { expect(matching).to yield_with_args(ln, 'Use action', anything) }
      end

      context 'otherwise' do
        it { expect(matching).not_to yield_control }
      end
    end

    context 'use where and count to check for exists' do
      let(:line) { 'where(attr: "attr").count > 0' }

      context 'rb' do
        let(:extension) { 'rb' }

        it { expect(matching).to yield_with_args(ln, 'Check exists', anything) }
      end

      context 'otherwise' do
        it { expect(matching).not_to yield_control }
      end
    end

    context 'use render partial in view' do
      let(:line) { '= render partial: "view"' }

      %w(erb haml slim).each do |lang|
        context lang do
          let(:extension) { lang }

          it { expect(matching).to yield_with_args(ln, 'Partial redundancy', anything) }
        end
      end

      context 'with collection' do
        let(:line) { '= render partial: "view", collection: "collection"' }

        it { expect(matching).not_to yield_control }
      end

      context 'otherwise' do
        it { expect(matching).not_to yield_control }
      end
    end

    context 'use render locals in view' do
      let(:line) { '= render "view", locals: { abc: 123 }' }

      %w(erb haml slim).each do |lang|
        context lang do
          let(:extension) { lang }

          it { expect(matching).to yield_with_args(ln, 'Locals redundancy', anything) }
        end
      end

      context 'otherwise' do
        it { expect(matching).not_to yield_control }
      end
    end

    context 'use be matchers' do
      context 'ruby' do
        let(:extension) { 'rb' }

        ['expect(Model.exists?).to be_truthy', 'expect(parent.assocs.abc?(xyz)).to eq true'].each do |value|
          context value do
            let(:line) { value }

            it { expect(matching).to yield_with_args(ln, 'Use to be matchers', anything) }
          end
        end
      end

      context 'otherwise' do
        let(:line) { 'expect(Author.exists?).to be_truthy' }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'use not be matchers' do
      context 'ruby' do
        let(:extension) { 'rb' }

        ['expect(Model.exists?).to be_falsy', 'expect(parent.assocs.abc?(xyz)).to be false'].each do |value|
          context value do
            let(:line) { value }

            it { expect(matching).to yield_with_args(ln, 'Use not_to be matchers', anything) }
          end
        end
      end

      context 'otherwise' do
        let(:line) { 'expect(Author.exists?).to be_falsey' }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'use FactoryGirl syntax' do
      context 'ruby' do
        let(:extension) { 'rb' }

        ['FactoryGirl.create :model', 'FactoryGirl.build_list(:model, 2)'].each do |value|
          context value do
            let(:line) { value }

            it { expect(matching).to yield_with_args(ln, 'Add factory girl syntax', anything) }
          end
        end
      end

      context 'otherwise' do
        let(:line) { 'FactoryGirl.build_list(:model, 2)' }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'use have_http_status' do
      context 'ruby' do
        let(:extension) { 'rb' }

        ['expect(response.status).to eq(200)', 'expect( response.status ).to eq 400'].each do |value|
          context value do
            let(:line) { value }

            it { expect(matching).to yield_with_args(ln, 'Use have_http_status', anything) }
          end
        end
      end

      context 'otherwise' do
        let(:line) { 'expect( response.status ).to eq 400' }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'hardcoded dimensions' do
      context 'xml' do
        let(:extension) { 'xml' }

        [' android:width="10dp"',"+\tfontSize='5sp'"].each do |value|
          context value do
            let(:line) { value }

            it { expect(matching).to yield_with_args(ln, 'Hardcoded dimensions', anything) }
          end
        end

        ['<dimen name="snake_case">50dp</dimen>', 'android:value="0dp"'].each do |value|
          context value do
            let(:line) { value }

            it { expect(matching).not_to yield_control }
          end
        end
      end

      context 'otherwise' do
        let(:line) { 'android:width="10dp"' }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'hardcoded dimensions' do
      context 'xml' do
        let(:extension) { 'xml' }

        [' android:text="My text"',"+\tpath='abc/xyz'"].each do |value|
          context value do
            let(:line) { value }

            it { expect(matching).to yield_with_args(ln, 'Hardcoded string', anything) }
          end
        end

        [
          'android:width="match_parent"',
          '+android:height="wrap_content"',
          'xmlns:text="My text"',
          'package="com.hoangphan.xx"',
          'android:versionCode="myversion"'
        ].each do |value|
          context value do
            let(:line) { value }

            it { expect(matching).not_to yield_control }
          end
        end
      end

      context 'otherwise' do
        let(:line) { 'android:width="10dp"' }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'with prefixer' do
      %w(css scss sass less).each do |lang|
        context lang do
          let(:extension) { lang }

          ['+-moz-border', '-webkit-gradient', '-ms-flex'].each do |value|
            context value do
              let(:line) { value }

              it { expect(matching).to yield_with_args(ln, 'Use auto prefixer gem', anything) }
            end
          end
        end
      end

      context 'otherwise' do
        let(:line) { '-moz-box-shadow: none' }

        it { expect(matching).not_to yield_control }
      end
    end

    context 'nil checking' do
      let(:line) { 'abc.nil?' }

      it { expect(matching).to yield_with_args(ln, 'Nil checking', anything) }
    end

    context 'blank checking' do
      ['!var||var.empty?','!var_1 || var_1.count == 0', '!var10 || var10.length<1'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use blank', anything) }
        end
      end

      ['var||var.count == 0', '!var1||var2.empty?', '!var1||var1.abc.empty?'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).not_to yield_control }
        end
      end
    end

    context 'present checking' do
      ['var&&!var.empty?','var_1 && var_1.count > 0', 'var10 && var10.length>=1'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use present', anything) }
        end
      end

      ['var&&var.count == 0', 'var&& !var2.empty?', 'var1 &&var1.abc.length > 0'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).not_to yield_control }
        end
      end
    end

    context 'has_many/has_one checking' do
      let(:extension) { 'rb' }

      ['has_many :models', 'has_one :model'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Add dependent destroy', anything) }
        end
      end

      ['has_many :model, dependent: :destroy'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use plural form', anything) }
        end
      end

      ['has_one :models, dependent: :destroy', 'belongs_to :models'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use singular form', anything) }
        end
      end

      ['has_one :model, dependent: :destroy', 'has_many :models, through: :modelbs'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).not_to yield_control }
        end
      end
    end

    context 'use to_i' do
      ['model.present? ? model.method : 0', 'mo_del.blank? ? 0 : mo_del.method',  '+model ? model.me_thod : 0'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use to_i', anything) }
        end
      end
    end

    context 'debug code' do
      {
        'js': ['console.log(1)'],
        'coffee': ["+\tconsole.log 1", ' console.log(2)'],
        'rb': ['+ p mdl.mtd', 'puts "abc"']
      }.each do |lang, values|
        context lang do
          let(:extension) { lang }
          
          values.each do |value|
            context value do
              let(:line) { value }

              it { expect(matching).to yield_with_args(ln, 'Debug code', anything) }
            end
          end
        end
      end
    end

    context 'id shorthand' do
      {
        'haml': ['+ %span.class{ id: "my_id" }'],
        'slim': ["\tspan.class(id='my-id')"]
      }.each do |lang, values|
        context lang do
          let(:extension) { lang }
          
          values.each do |value|
            context value do
              let(:line) { value }

              it { expect(matching).to yield_with_args(ln, 'Id shorthand', anything) }
            end
          end
        end
      end

      {
        'haml': ['  %span.class{ id: id }'],
        'slim': ['span.class(id= id)']
      }.each do |lang, values|
        context lang do
          let(:extension) { lang }
          
          values.each do |value|
            context value do
              let(:line) { value }

              it { expect(matching).not_to yield_control }
            end
          end
        end
      end
    end

    context 'class shorthand' do
      {
        'haml': ['+ %span.class{ class: "my-class" }'],
        'slim': ["\tspan.class(class='my-class class2')"]
      }.each do |lang, values|
        context lang do
          let(:extension) { lang }
          
          values.each do |value|
            context value do
              let(:line) { value }

              it { expect(matching).to yield_with_args(ln, 'Class shorthand', anything) }
            end
          end
        end
      end

      {
        'haml': ['  %span.class{ class: id }'],
        'slim': ['span.class(class= id)']
      }.each do |lang, values|
        context lang do
          let(:extension) { lang }
          
          values.each do |value|
            context value do
              let(:line) { value }

              it { expect(matching).not_to yield_control }
            end
          end
        end
      end
    end

    context 'sleep' do
      let(:extension) { 'rb' }

      ['+sleep 1', "\t  sleep(2)"].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use wait for ajax', anything) }
        end
      end

      ['Thread.sleep 1', '#  sleep(2)'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).not_to yield_control }
        end
      end
    end

    context 'pluck id' do
      let(:extension) { 'rb' }

      ['Book.pluck(:id)', "categories.where(type: abc).pluck :id"].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).to yield_with_args(ln, 'Use ids', anything) }
        end
      end

      ['Book.pluck(:my_id)', 'categories.pluck :my_id', 'categories.pluck :id1'].each do |value|
        context value do
          let(:line) { value }

          it { expect(matching).not_to yield_control }
        end
      end
    end
  end
end
