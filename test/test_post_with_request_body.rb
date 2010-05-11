require File.join(File.dirname(__FILE__), "test_helper")

class TestPostWithRequestBody < Test::Unit::TestCase
  def test_register_uri_with_params_hash_should_not_be_registered_without_them
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'foo', :data => { :a => 1, :b => 1 })
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'bar', :data => { :c => 1, :d => 1 })

    assert !FakeWeb.registered_uri?(:post, 'http://mock/')
    assert  FakeWeb.registered_uri?(:post, 'http://mock/', :data => { :a => 1, :b => 1 })
    assert  FakeWeb.registered_uri?(:post, 'http://mock/', :data => { :c => 1, :d => 1 })
  end
  
  def test_register_without_any_data
    # no data in expectation and no data during request.
    FakeWeb.register_uri(:any, 'http://mock/', :body => 'baz')

    Net::HTTP.start('mock') do |query|
      response = query.get('/')
      assert_equal 'baz', response.body
    end
  end
  
  def test_register_should_use_matching_data_first
    # Nil or missing data should match, but only if it's not first matched by something more precise.
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'foo', :data => { :a => 1, :b => 1 })
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'bar', :data => { :c => 1, :d => 1 })
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'baz')

    Net::HTTP.start('mock') do |query|
      response = query.post('/', :a => 1, :b => 1)
      assert_equal 'foo', response.body
      
      response = query.post('/', :c => 1, :d => 1)
      assert_equal 'bar', response.body
      
      response = query.post('/', :e => 1, :f => 1)
      assert_equal 'baz', response.body
      
      response = query.post('/', :g => 1, :h => 1)
      assert_equal 'baz', response.body
    end
  end
  
  def test_register_without_data
    # Basically, if data expectation is nil or not specified, then it should return canned response
    # for all data.
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'baz')

    Net::HTTP.start('mock') do |query|
      response = query.post('/', { :e => 1, :f => 1 })
      assert_equal 'baz', response.body
    end
  end
  
  def test_register_any_method_with_data
    FakeWeb.register_uri(:any, 'http://mock/', :body => 'baz', :data => { :e => 1, :f => 1 })

    Net::HTTP.start('mock') do |query|
      response = query.post('/', { :e => 1, :f => 1 })
      assert_equal "baz", response.body
      
      response = query.put('/', {:e => 1, :f => 1})
      assert_equal "baz", response.body
    end
  end
  
  def test_register_multiple_methods_with_different_bodies_and_same_data
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'foo', :data => { :a => 1, :b => 1 })
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'bar', :data => { :c => 1, :d => 1 })
    FakeWeb.register_uri(:put,  'http://mock/', :body => 'baz', :data => { :e => 1, :f => 1 })

    Net::HTTP.start('mock') do |query|
      response = query.post('/', { :a => 1, :b => 1 })
      assert_equal 'foo', response.body
      
      # Should raise, because it's expecting a *post* with this data, not a *put*.
      assert_raises FakeWeb::NetConnectNotAllowedError do
        query.put('/', { :c => 1, :d => 1})
      end
      
      response = query.put('/', { :e => 1, :f => 1 })
      assert_equal 'baz', response.body
    end
  end

  def test_same_uri_with_different_data
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'foo', :data => { :a => 1, :b => 1 })
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'bar', :data => { :c => 1, :d => 1 })

    Net::HTTP.start('mock') do |query|
      response = query.post('/', { :a => 1, :b => 1 })
      assert_equal 'foo', response.body
      
      response = query.post('/', { :c => 1, :d => 1 })
      assert_equal 'bar', response.body
    end
  end
  
  def test_same_uri_with_same_data
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'foo', :data => { :a => 1, :b => 1 })
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'bar', :data => { :c => 1, :d => 1 })

    Net::HTTP.start('mock') do |query|
      response = query.post('/', { :a => 1, :b => 1 })
      assert_equal 'foo', response.body
      
      response = query.post('/', { :c => 1, :d => 1 })
      assert_equal 'bar', response.body
    end
  end
  
  def test_using_post_form
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'foo', :data => { :a => 1, :b => 1 })

    assert_equal "foo", Net::HTTP.post_form(URI.parse("http://mock/"), { :a => 1, :b => 1}).body
  end

  def test_using_post_form_with_nested_hash
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'foo', :data => { :a => 1, :b => 1 })

    assert_equal "foo", Net::HTTP.post_form(URI.parse("http://mock/"), { :a => 1, :b => 1}).body
  end

  def test_register_uri_with_string_for_data
    FakeWeb.register_uri(:post, 'http://mock/', :body => 'baz', :data => "hello world")

    Net::HTTP.start('mock') do |query|
      response = query.post('/', 'hello world')
      assert_equal 'baz', response.body
    end
  end
end
