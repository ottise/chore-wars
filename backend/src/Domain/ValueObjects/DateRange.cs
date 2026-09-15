using System;
using System.Collections.Generic;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Domain.ValueObjects;

public class DateRange
{
    public DateTime StartDate { get; private set; }
    public DateTime EndDate { get; private set; }

    private DateRange(DateTime startDate, DateTime endDate)
    {
        StartDate = startDate;
        EndDate = endDate;
    }

    public static DateRange Create(DateTime startDate, DateTime endDate)
    {
        if (startDate > endDate)
        {
            throw new ValidationException(new Dictionary<string, string[]>
            {
                { "EndDate", new[] { "EndDate must be after or equal to StartDate." } }
            });
        }

        return new DateRange(startDate, endDate);
    }
}
