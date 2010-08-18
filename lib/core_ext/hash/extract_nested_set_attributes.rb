class Hash
  def extract_nested_set_attributes!
    slice(*SimpleNestedSet::ATTRIBUTES).tap do
      except!(*SimpleNestedSet::ATTRIBUTES)
    end
  end
end

