# encoding: utf-8
require 'cliver'
require 'spec_helper'

describe Cliver do
  # The setup. Your test will likeley interact with subject.
  let(:action) { Cliver.public_send(method, *args, &block) }
  subject { action }

  # These can get overridden in context blocks
  let(:method) { raise ArgumentError, 'spec didn\'t specify :method' }
  let(:args) { raise ArgumentError, 'spec didn\'t specify :args' }
  let(:block) { version_map.method(:fetch) }

  before(:each) do
    File.stub(:executable?) { |path| executables.include? path }
    # Cliver::Dependency.any_instance.stub(:detect_version) do |arg|
    #   version_map[arg]
    # end
  end

  let(:options) do
    {
      :path =>       path,
      :executable => executable,
    }
  end
  let(:executables) { version_map.keys }
  let(:args) do
    args = [Array(executable)]
    args.concat Array(requirement)
    args << options
  end

  let(:path) { '/foo/bar:/baz/bingo' }
  let(:executable) { 'doodle' }
  let(:requirement) { '~>1.1'}

  context 'when first-found version is sufficient' do

    let(:version_map) do
      {'/baz/bingo/doodle' => '1.2.1'}
    end

    context '::assert' do
      let(:method) { :assert }
      it 'should not raise' do
        expect { action }.to_not raise_exception
      end
    end

    context '::dependency_unmet?' do
      let(:method) { :dependency_unmet? }
      it { should be_false }
    end
    context '::detect' do
      let(:method) { :detect }
      it { should eq '/baz/bingo/doodle' }
    end
    context '::detect!' do
      let(:method) { :detect! }
      it 'should not raise' do
        expect { action }.to_not raise_exception
      end
      it { should eq '/baz/bingo/doodle' }
    end
  end

  context '::verify!' do
    let(:method) { :verify! }
    let(:version_map) do
      {'/baz/bingo/doodle' => '0.2.1',
       '/baz/fiddle/doodle' => '1.1.4'}
    end
    let(:args) do
      args = [executable]
      args.concat Array(requirement)
      args << options
    end
    context 'when a relative path is given' do
      let(:executable) { 'foo/bar/doodle' }
      it 'should raise' do
        expect { action }.to raise_exception ArgumentError
      end
    end
    context 'when an absolute path is given' do
      context 'and that path is not found' do
        let(:executable) { '/blip/boom' }
        it 'should raise' do
          expect { action }.to raise_exception Cliver::Dependency::NotFound
        end
      end
      context 'and the executable at that path is sufficent' do
        let(:executable) { '/baz/fiddle/doodle' }
        it 'should not raise' do
          expect { action }.to_not raise_exception Cliver::Dependency::NotFound
        end
      end
      context 'and the executable at that path is not sufficent' do
        let(:executable) { '/baz/bingo/doodle' }
        it 'should raise' do
          expect { action }.to raise_exception Cliver::Dependency::VersionMismatch
        end
      end
    end
  end

  context 'when given executable as a path' do
    let(:version_map) do
      {'/baz/bingo/doodle' => '1.2.1'}
    end
    let(:path) { '/fiddle/foo:/deedle/dee'}

    context 'that is absolute' do
      let(:executable) { '/baz/bingo/doodle' }
      %w(assert dependency_unmet? detect detect).each do |method_name|
        context "::#{method_name}" do
          let(:method) { method_name.to_sym }
          it 'should only detect its version once' do
            Cliver::Dependency.any_instance.
              should_receive(:detect_version).
              once.
              and_call_original
            action
          end
        end
      end
    end

    context 'that is relative' do
      let(:executable) { 'baz/bingo/doodle' }
      %w(assert dependency_unmet? detect detect).each do |method_name|
        context "::#{method_name}" do
          let(:method) { method_name.to_sym }
          it 'should raise an ArgumentError' do
            expect { action }.to raise_exception ArgumentError
          end
        end
      end
    end
  end

  context 'when first-found version insufficient' do
    let(:version_map) do
      {'/baz/bingo/doodle' => '1.0.1'}
    end
    context '::assert' do
      let(:method) { :assert }
      it 'should raise' do
        expect { action }.to raise_exception Cliver::Dependency::VersionMismatch
      end
    end
    context '::dependency_unmet?' do
      let(:method) { :dependency_unmet? }
      it { should be_true }
    end
    context '::detect' do
      let(:method) { :detect }
      it { should be_nil }
    end
    context '::detect!' do
      let(:method) { :detect! }
      it 'should not raise' do
        expect { action }.to raise_exception Cliver::Dependency::VersionMismatch
      end
    end

    context 'and when sufficient version found later on path' do
      let(:version_map) do
        {
          '/foo/bar/doodle'    => '0.0.1',
          '/baz/bingo/doodle'  => '1.1.0',
        }
      end
      context '::assert' do
        let(:method) { :assert }
        it 'should raise' do
          expect { action }.to raise_exception Cliver::Dependency::VersionMismatch
        end
      end
      context '::dependency_unmet?' do
        let(:method) { :dependency_unmet? }
        it { should be_true }
      end
      context '::detect' do
        let(:method) { :detect }
        it { should eq '/baz/bingo/doodle'}
      end
      context '::detect!' do
        let(:method) { :detect! }
        it 'should not raise' do
          expect { action }.to_not raise_exception
        end
        it { should eq '/baz/bingo/doodle' }
      end
    end
  end

  context 'when no found version' do
    let(:version_map) { {} }

    context '::assert' do
      let(:method) { :assert }
      it 'should raise' do
        expect { action }.to raise_exception Cliver::Dependency::NotFound
      end
    end
    context '::dependency_unmet?' do
      let(:method) { :dependency_unmet? }
      it { should be_true }
    end
    context '::detect' do
      let(:method) { :detect }
      it { should be_nil }
    end
    context '::detect!' do
      let(:method) { :detect! }
      it 'should not raise' do
        expect { action }.to raise_exception Cliver::Dependency::NotFound
      end
    end
  end

  context 'with fallback executable names' do
    let(:executable) { ['primary', 'fallback'] }
    let(:requirement) { '~> 1.1' }
    context 'when primary exists after secondary in path' do
      context 'and primary sufficient' do
        let(:version_map) do
          {
            '/baz/bingo/primary' => '1.1',
            '/foo/bar/fallback' => '1.1'
          }
        end
        context '::detect' do
          let(:method) { :detect }
          it { should eq '/baz/bingo/primary' }
        end
      end
      context 'and primary insufficient' do
        let(:version_map) do
          {
            '/baz/bingo/primary' => '2.1',
            '/foo/bar/fallback' => '1.1'
          }
        end
        context 'the secondary' do
          context '::detect' do
            let(:method) { :detect }
            it { should eq '/foo/bar/fallback' }
          end
        end
      end
    end
    context 'when primary does not exist in path' do
      context 'and sufficient secondary does' do
        let(:version_map) do
          {
            '/foo/bar/fallback' => '1.1'
          }
        end
        context '::detect' do
          let(:method) { :detect }
          it { should eq '/foo/bar/fallback' }
        end
      end
    end

    context 'neither found' do
      context '::detect' do
        let(:version_map) { {} }
        let(:method) { :detect }
        it { should be_nil }
      end
    end
  end
end
