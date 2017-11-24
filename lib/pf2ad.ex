defmodule PF2AD do
  @moduledoc """
  This module is intended to be called as a command line program or a batch job.
  It pulls employee data from the authoritative Exchange public folder maintained by HR,
  and reflects any updates to each employee's job tile, mobile phone, and home phone in
  Active Directory. Information in AD will appear in the Outlook GAL, Skype for Business,
  Teams, and SharePoint.
  """

  require Logger

  def main(_args) do
    Logger.configure(level: :info)
    source_data = PF2AD.PFContacts.fetch_contacts
    target_data = PF2AD.LDAP.get_all_employees
    PF2AD.Diff.calculate_diff(source_data, target_data)
    |> PF2AD.LDAP.make_changes
    Logger.flush()
  end
end
