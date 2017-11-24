defmodule PF2AD.User do
  @moduledoc """
  A struct used to compare user data obtained from the source and target systems in a
  standardized format.
  """

  require Logger

  @field_to_match :email
  @fields_to_equal [:job_title, :mobile_phone, :home_phone]


  defstruct cn: "",
            first_name: "",
            last_name: "",
            job_title: "",
            email: "",
            mobile_phone: "",
            home_phone: "",
            disabled: false


  @doc """
  Converts a standard atom keyed map into a User struct.
  """
  def from_map(map) when is_map(map) do
    Enum.reduce(map, %__MODULE__{}, fn({key, val}, acc) -> put(acc, key, val) end)
  end

  @doc """
  Inserts a value into the struct, with a few conveniences to keep values standardized:
   - null values are converted to an empty string
   - The value for the :email key is downcased
  """
  def put(struct, key, val) do
    case val do
      nil -> Map.put(struct, key, "")
      _other ->
        case key do
          :email -> Map.put(struct, key, (val |> String.downcase))
          __other -> Map.put(struct, key, (val))
        end
    end
  end

  @doc """
  Checks whether two User structs match on the primary key field
  """
  def match?(s1, s2) do
    Map.get(s1, @field_to_match) == Map.get(s2, @field_to_match)
  end

  @doc """
  Checks whether two User structs are equal based on the list of configured keys
  """
  def equals?(s1, s2) do
    Enum.all?(@fields_to_equal, &(equals?(s1, s2, &1)))
  end

  @doc """
  Checks whether two User structs have an equal value for a given key
  """
  def equals?(s1, s2, key) do
    Map.get(s1, key) == Map.get(s2, key)
  end

  @doc """
  Checks two user structs for any differences in fields.
  If the structs are equal, returns {:match, target}.
  Otherwise, returns {:diff, target, diffs}, where diffs is a list of fields with differences
  in the format {:diff, field, source_value}
  """
  def check_pair_for_diffs({source, target}) do
    email = Map.get(source,@field_to_match)
    Logger.debug("Starting comparison of user #{email}")
    fields = @fields_to_equal
    field_results = Enum.map(fields, &check_field_for_diffs(&1,source,target))
    field_diffs = Enum.filter_map(field_results, &(elem(&1,0)==:diff),&{elem(&1,1),elem(&1,2)})
    case field_diffs do
      [] ->
        Logger.debug("All fields match for user #{email}.")
        {:match, target}
      _results ->
        Logger.debug("User #{email} needs to be updated.")
        {:diff,target,field_diffs}
    end
  end

  defp check_field_for_diffs(field,source,target) do
    email = Map.get(source,@field_to_match)
    source_value = Map.get(source, field)
    target_value = Map.get(target, field)
    cond do
      source_value == target_value ->
        {:match, field, target_value}
      true ->
        Logger.info("User #{email}: Field #{field} will change from #{inspect(target_value)} to #{inspect(source_value)}.")
        {:diff, field, source_value}
    end
  end

end
