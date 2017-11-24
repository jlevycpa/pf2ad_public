defmodule PF2AD.LDAP do
  @moduledoc """
  Performs LDAP read/write operations along with related encoding and decoding.
  """

  require Logger
  require Record
  use Bitwise
  alias PF2AD.User

  @dn Application.get_env(:pf2ad, :dn) |> to_char_list
  @pw Application.get_env(:pf2ad, :password) |> to_char_list
  @eb_group Application.get_env(:pf2ad, :eb_group) |> to_char_list
  @somerset_group Application.get_env(:pf2ad, :somerset_group) |> to_char_list
  @base Application.get_env(:pf2ad, :base_dn) |> to_char_list
  @ldap_server Application.get_env(:pf2ad, :ldap_server) |> to_char_list

  Record.defrecord :eldap_entry, Record.extract(:eldap_entry, from_lib: "eldap/include/eldap.hrl")
  Record.defrecord :eldap_search_result, Record.extract(:eldap_search_result, from_lib: "eldap/include/eldap.hrl")


  @doc """
  Fetches all of the user records from AD via LDAP that are members of the configured groups.
  The result is returned as a list of PF2AD.User structs.
  Disabled users are not included in the result.
  """
  def get_all_employees do
    handle = connect()

    {handle, results} = get_group_members(handle, @eb_group)
    eb_results = results |> search_results_to_list()
    
    {handle, results} = get_group_members(handle, @somerset_group)
    somerset_results = results |> search_results_to_list()

    disconnect(handle)

    eb_results ++ somerset_results
    |> filter_disabled_users
    |> filter_non_users
  end

  @doc """
  Executes a list of changes to AD users via LDAP. Elements in the list are formatted as a tuple
  {:diff, user, changes} where user is a PF2AD.User struct and changes is a list of {attribute, value} tuples.
  """
  def make_changes(changes) do
    connect
    |> do_make_changes(changes)
    |> disconnect
  end

  defp connect do
    case :eldap.open([@ldap_server],[ssl: true, port: 636, log: &Logger.log/3]) do
      {:ok, handle} -> bind(handle)
    end
  end

  defp disconnect(handle) do
    :eldap.close(handle)
  end

  defp bind(handle) do
    case :eldap.simple_bind(handle, @dn, @pw) do
      :ok -> handle
    end
  end

  defp get_group_members(handle, group) do
    attrs = ['userAccountControl', 'givenName', 'sn', 'title', 'mail', 'mobile', 'homePhone', 'objectclass']
    case :eldap.search(handle, [base: @base, filter: :eldap.equalityMatch('memberOf', group), attributes: attrs]) do
      {:ok, results} -> {handle, results}
    end

  end

  defp do_make_changes(handle, changes) do
    changes |> Enum.map(&(change_user(&1, handle)))
    handle
  end

  defp change_user({:diff, user, changes}, handle) do
    cn = to_char_list(user.cn)
    encoded_changes = Enum.map(changes, &encode_attribute/1)
    Logger.info("Executing changes for user #{user.email}")
    case (:eldap.modify(handle, cn, encoded_changes)) do
      :ok -> Logger.info("Changes were successful")
      other ->
        Logger.error("Error setting properties for user #{user.email}: #{inspect other}")
        Logger.error("cn was #{cn}")
        Logger.error("changes were #{inspect encoded_changes}")
    end
  end

  defp search_results_to_list(results) do
    list = eldap_search_result(results, :entries)
    Enum.map(list, &search_result_to_map/1)
  end

  defp search_result_to_map(result) do
    cn = eldap_entry(result, :object_name) |> to_string
    attrs = eldap_entry(result, :attributes)
    |> Enum.map(&decode_attribute/1)

    Enum.into(attrs, %{})
    |> Map.put(:cn, cn)
    |> extract_disabled
    |> User.from_map
  end

  defp decode_attribute({'objectClass', values}) do
    cond do
      'user' in values -> {:object_class, "user"}
      'contact' in values -> {:object_class, "contact"}
      true -> {:object_class, "unknown"}
    end
  end

  defp decode_attribute({attr, [value | _]}) do
    case attr do
      'userAccountControl' -> {:user_account_control, List.to_integer(value)}
      'givenName' -> {:first_name, to_string(value)}
      'sn' -> {:last_name, to_string(value)}
      'title' -> {:job_title, to_string(value)}
      'mail' -> {:email, to_string(value)}
      'mobile' -> {:mobile_phone, to_string(value)}
      'homePhone' -> {:home_phone, to_string(value)}
    end
  end

  defp encode_attribute({attr, value}) do
    new_attr = case attr do
      :job_title -> 'title'
      :mobile_phone -> 'mobile'
      :home_phone -> 'homePhone'
    end

    new_value = to_char_list(value)

    case new_value do
      [] -> :eldap.mod_replace(new_attr, [])
      other -> :eldap.mod_replace(new_attr, [new_value])
    end
  end



  defp extract_disabled(%{object_class: "user"} = user) do
    uac = user.user_account_control
    # UAC is a bitwise field. 
    # https://support.microsoft.com/en-us/help/305144/how-to-use-the-useraccountcontrol-flags-to-manipulate-user-account-pro
    disabled = 2
    case uac &&& disabled do
      2 ->
        Logger.warn("User #{user.email} is disabled")
        Map.put(user, :disabled, true)
      0 ->
        Map.put(user, :disabled, false)
    end
  end

  defp extract_disabled(non_user), do: non_user

  defp filter_disabled_users(data) do
    Enum.filter(data, &(Map.get(&1,:disabled)==false))
  end

  defp filter_non_users(data) do
    Enum.filter(data, &(Map.get(&1,:object_class)=="user"))
  end
  

end
