defmodule PF2AD.ExportCSV do
  @moduledoc """
  Utility functions for debugging purposes only.
  """

  @doc """
  Converts a list of User structs to a 2d list ready to be serialized into a CSV, including a header row.
  """
  def to_2d_list (data) do
    headers = ["firstName", "lastName", "emailAddress", "jobTitle", "mobilePhone", "homePhone"]
    rows = data |> Enum.map(&map_to_list/1)
    [headers | rows]
  end

  defp map_to_list (item) do
    [item.firstName, item.lastName, item.emailAddress, item.jobTitle, item.mobilePhone, item.homePhone]
  end


end
