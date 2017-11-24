defmodule PF2AD.PFContacts do
  @moduledoc """
  Fetches contact records from a Microsoft Exchange public folder via EWS
  and returns them as PF2AD.User structs.
  """

  require Logger
  alias PF2AD.User

  @doc """
  Fetches contact records from a Microsoft Exchange public folder via EWS
  and returns them as PF2AD.User structs.
  """
  def fetch_contacts() do
    PF2AD.EWS.get_all_employees
    |> cleanup_email_addresses    # Converts the array of email addresses returned by EWS to a single address
                                  # representing the user's primary SMTP address.
                                  
    |> cleanup_all_phone_numbers  # Converts the array of phone numbers returned by EWS to individual mobile_phone and home_phone
                                  # properties
    |> convert_to_user_structs
  end

  defp cleanup_email_addresses(contacts) do
    contacts
    |> Enum.map(&cleanup_email_address/1)
    |> Enum.filter(&(Map.get(&1,:email))) #filter out if emailAddress is nil
  end

  defp cleanup_email_address(contact = %{email_addresses: email_addresses}) do
    primary_email = email_addresses
    |> Enum.map(&classify_emails/1) # classifies each email address as an EX500 address, wgcpas (primary), or a personal address
    |> get_primary_email

    if (!primary_email) do
      Logger.warn("Contact #{contact.first_name} #{contact.last_name} does not have a valid company email listed.")
    end

    contact
    |> Map.delete(:email_addresses)
    |> Map.put(:email, primary_email)
  end

  
  defp classify_emails(email_address = "/" <> _rest) do
    {:ex, email_address}
  end

  defp classify_emails(email_address) do
    cond do
      String.match?(email_address, ~r/.*@wgcpas.com/) -> {:wgcpas, email_address}
      true -> {:personal, email_address}
    end
  end

  defp get_primary_email(email_addresses) do
    corp = Enum.find(email_addresses, fn item -> elem(item,0) == :wgcpas end)
    if corp do
      elem(corp,1)
    else
      ex = Enum.find(email_addresses, fn item -> elem(item,0) == :ex end)
      if ex do
        # If there is no corporate email listed, but there is an EX500 address, we can call EWS to convert the
        # EX500 address into it's corresponding primary SMTP address.
        result = elem(ex,1) |> PF2AD.EWS.convert_ex_address
        cond do
          String.match?(result, ~r/.*@wgcpas.com/) -> result
          true -> nil
        end

      else
        nil
      end
    end
  end

  defp cleanup_all_phone_numbers(contacts) do
    contacts
    |> Enum.map(&cleanup_phone_numbers/1)
  end

  defp cleanup_phone_numbers(contact) do
    contact
    |> extract_mobile
    |> extract_home
    |> Map.delete(:phoneNumbers)

  end

  defp extract_mobile(contact) do
    numbers = contact.phone_numbers
    mobile = Enum.find(numbers, fn number -> number.type == "MobilePhone" end)

    case mobile do
      nil -> Map.put(contact, :mobile_phone, "")
      num -> Map.put(contact, :mobile_phone, num.value)
    end
  end

  defp extract_home(contact) do
    numbers = contact.phone_numbers
    home = Enum.find(numbers, fn number -> number.type == "HomePhone" end)

    case home do
      nil-> Map.put(contact, :home_phone, "")
      num -> Map.put(contact, :home_phone, num.value)
    end

  end

  defp convert_to_user_structs(data) do
    Enum.map(data, &User.from_map/1)
  end

end
